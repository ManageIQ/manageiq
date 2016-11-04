module EmsRefresh::SaveInventoryHelper
  class TypedIndex
    attr_accessor :record_index, :key_attribute_types
    attr_accessor :find_key
    def initialize(records, find_key)
      # Save the columns associated with the find keys, so we can coerce the hash values during fetch
      if records.first
        model = records.first.class
        @key_attribute_types = find_key.map { |k| model.type_for_attribute(k) }
      else
        @key_attribute_types = []
      end

      # Index the records by the values from the find_key
      @record_index = records.each_with_object({}) do |r, h|
        h.store_path(find_key.collect { |k| r.send(k) }, r)
      end

      @find_key = find_key
    end

    def fetch(hash)
      return nil if record_index.blank?

      hash_values = find_key.collect { |k| hash[k] }

      # Coerce each hash value into the db column type for valid lookup during fetch_path
      coerced_hash_values = hash_values.zip(key_attribute_types).collect do |value, type|
        type.cast(value)
      end

      record_index.fetch_path(coerced_hash_values)
    end
  end

  def save_dto_inventory_with_findkey(dto_collection, dto, association, new_records, record_index,
                                      method = nil)
    hash   = dto.kind_of?(::ManagerRefresh::Dto) ? dto.attributes(dto_collection) : dto
    # Find the record, and update if found, else create it
    method ||= :build
    # TODO(lsmola) probably move all this under dto, so it can create or save right here?
    found = record_index.delete(dto.manager_uuid)
    if found.nil?
      dto.build_object(association.public_send(method, hash.except(:id)))
      new_records << dto
    else
      # TODO(lsmola) Build object, that is really bad name. it should either really build the object or it could be just
      # the object setter
      dto.build_object(found)
      found.update_attributes!(hash.except(:id, :type))
    end
    found
  end

  def save_dto_inventory_multi_batch(dto_collection)
    dto_collection.parent.reload
    association = dto_collection.parent.send(dto_collection.association)

    record_index = {}
    unique_index_keys = dto_collection.manager_ref_to_cols

    association.find_each do |record|
      # TODO(lsmola) the old code was able to deal with duplicate records, should we do that? The old data still can
      # have duplicate methods, so we should clean them up. It will slow up the indexing though.
      record_index[dto_collection.object_index_with_keys(unique_index_keys, record)] = record
    end

    new_records = []
    _log.info("PROCESSING #{dto_collection}")
    ActiveRecord::Base.transaction do
      dto_collection.each do |dto|
        association_meta_info = dto_collection.parent.class.reflect_on_association(dto_collection.association)

        if association_meta_info.options[:through].blank?
          entity_builder = association
          method         = :build
        else
          entity_builder = dto_collection.model_class
          method         = :new
        end

        save_dto_inventory_with_findkey(dto_collection, dto, entity_builder, new_records, record_index, method)
      end
    end
    _log.info("PROCESSED #{dto_collection}")

    # Delete the items no longer found
    unless record_index.blank?
      deletes = record_index.values
      type = association.proxy_association.reflection.name
      _log.info("[#{type}] Deleting with method '#{dto_collection.delete_method}' #{log_format_deletes(deletes)}")
      ActiveRecord::Base.transaction do
        deletes.map(&dto_collection.delete_method)
      end
    end

    _log.info("CREATING #{dto_collection} of size #{new_records.size}")
    ActiveRecord::Base.transaction do
      new_records.map(&:save)
    end
    _log.info("CREATED #{dto_collection}")
  end

  def save_inventory_multi(association, hashes, deletes, find_key, child_keys = [], extra_keys = [], disconnect = false)
    association.reset

    if deletes == :use_association
      deletes = association
    elsif deletes.respond_to?(:reload) && deletes.loaded?
      deletes.reload
    end
    deletes = deletes.to_a

    child_keys = Array.wrap(child_keys)
    remove_keys = Array.wrap(extra_keys) + child_keys

    record_index = TypedIndex.new(association, find_key)

    new_records = []
    hashes.each do |h|
      found = save_inventory_with_findkey(association, h.except(*remove_keys), deletes, new_records, record_index)
      save_child_inventory(found, h, child_keys)
    end

    # Delete the items no longer found
    unless deletes.blank?
      type = association.proxy_association.reflection.name
      _log.info("[#{type}] Deleting #{log_format_deletes(deletes)}")
      disconnect ? deletes.each(&:disconnect_inv) : association.delete(deletes)
    end

    # Add the new items
    association.push(new_records)
  end

  def save_inventory_single(type, parent, hash, child_keys = [], extra_keys = [], disconnect = false)
    child = parent.send(type)
    if hash.blank?
      disconnect ? child.try(:disconnect_inv) : child.try(:destroy)
      return
    end

    child_keys = Array.wrap(child_keys)
    remove_keys = Array.wrap(extra_keys) + child_keys + [:id]
    if child
      child.update_attributes!(hash.except(:type, *remove_keys))
    else
      child = parent.send("create_#{type}!", hash.except(*remove_keys))
    end
    save_child_inventory(child, hash, child_keys)
  end

  def save_inventory_with_findkey(association, hash, deletes, new_records, record_index)
    # Find the record, and update if found, else create it
    found = record_index.fetch(hash)
    if found.nil?
      found = association.build(hash.except(:id))
      new_records << found
    else
      found.update_attributes!(hash.except(:id, :type))
      deletes.delete(found) unless deletes.blank?
    end
    found
  end

  def backup_keys(hash, keys)
    keys.each_with_object({}) { |k, backup| backup[k] = hash.delete(k) if hash.key?(k) }
  end

  def restore_keys(hash, keys, backup)
    keys.each { |k| hash[k] = backup.delete(k) if backup.key?(k) }
  end

  def save_child_inventory(obj, hashes, child_keys, *args)
    child_keys.each { |k| send("save_#{k}_inventory", obj, hashes[k], *args) if hashes.key?(k) }
  end

  def store_ids_for_new_records(records, hashes, keys)
    keys = Array(keys)
    hashes.each do |h|
      r = records.detect { |r| keys.all? { |k| r.send(k) == r.class.type_for_attribute(k.to_s).cast(h[k]) } }
      h[:id]      = r.id
      r.send(:clear_association_cache)
      h[:_object] = r
    end
  end

  def link_children_references(records)
    records.each do |rec|
      parent = records.detect { |r| r.manager_ref == rec.parent_ref } if rec.parent_ref.present?
      rec.update_attributes(:parent_id => parent.try(:id))
    end
  end

  # most of the refresh_inventory_multi calls follow the same pattern
  # this pulls it out
  def save_inventory_assoc(association, hashes, target, find_key = [], child_keys = [], extra_keys = [])
    deletes = relation_values(association, target)
    save_inventory_multi(association, hashes, deletes, find_key, child_keys, extra_keys)
    store_ids_for_new_records(association, hashes, find_key)
  end

  # We need to determine our intent:
  # - make a complete refresh. Delete missing records.
  # - make a partial refresh. Don't delete missing records.
  # This generates the "deletes" values based upon this intent
  # It will delete missing records if both of the following are true:
  # - The association is declared as a top_level association
  #   In Active Record, :dependent => :destroy says the parent controls the lifespan of the children
  # - We are targeting this association
  #   If we are targeting something else, chances are it is a partial refresh. Don't delete.
  #   If we are targeting this node, or targeting anything (nil), then delete.
  #   Some places don't have the target==parent concept. So they can pass in true instead.
  def relation_values(association, target)
    # always want to refresh this association
    # if this association isn't the definitive source
    top_level = association.proxy_association.options[:dependent] == :destroy

    top_level && (target == true || target.nil? || parent == target) ? :use_association : []
  end

  def get_cluster(ems, cluster_hash, rp_hash, dc_hash)
    cluster = EmsCluster.find_by(:ems_ref => cluster_hash[:ems_ref], :ems_id => ems.id)
    if cluster.nil?
      rp = ems.resource_pools.create!(rp_hash)

      cluster = ems.clusters.create!(cluster_hash)

      cluster.add_resource_pool(rp)
      cluster.save!

      dc = Datacenter.find_by(:ems_ref => dc_hash[:ems_ref], :ems_id => ems.id)
      dc.add_cluster(cluster)
      dc.save!
    end

    cluster
  end
end
