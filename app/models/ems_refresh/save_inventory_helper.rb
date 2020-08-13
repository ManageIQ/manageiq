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

  def save_inventory_multi(association, hashes, deletes, find_key, child_keys = [], extra_keys = [], disconnect = false)
    association.reset

    if deletes == :use_association
      deletes = association
    elsif deletes.respond_to?(:reload) && deletes.loaded?
      deletes.reload
    end
    deletes = deletes.to_a
    deletes_index = deletes.index_by { |x| x }
    # Alow GC to clean the AR objects as they are removed from deletes_index
    deletes = nil

    child_keys = Array.wrap(child_keys)
    remove_keys = Array.wrap(extra_keys) + child_keys

    record_index = TypedIndex.new(association, find_key)

    new_records = []

    ActiveRecord::Base.transaction do
      hashes.each do |h|
        found = save_inventory_with_findkey(association, h.except(*remove_keys), deletes_index, new_records, record_index)
        save_child_inventory(found, h, child_keys)
      end
    end

    # Delete the items no longer found
    deletes = deletes_index.values
    unless deletes.blank?
      ActiveRecord::Base.transaction do
        type = association.proxy_association.reflection.name
        _log.info("[#{type}] Deleting #{log_format_deletes(deletes)}")
        disconnect ? deletes.each(&:disconnect_inv) : association.delete(deletes)
      end
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
      update!(child, hash, [:type, *remove_keys])
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
      update!(found, hash, [:id, :type])
      deletes.delete(found) unless deletes.blank?
    end
    found
  end

  def update!(ar_model, attributes, remove_keys)
    ar_model.assign_attributes(attributes.except(*remove_keys))
    # HACK: Avoid empty BEGIN/COMMIT pair until fix is made for https://github.com/rails/rails/issues/17937
    ar_model.save! if ar_model.changed?
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
    return if records.blank?

    keys = Array(keys)
    # Lets first index the hashes based on keys, so we can do O(1) lookups
    record_index = records.index_by { |record| build_index_from_record(keys, record) }
    record_class = records.first.class.base_class

    hashes.each do |hash|
      record = record_index[build_index_from_hash(keys, hash, record_class)]
      hash[:id] = record.id
    end
  end

  def build_index_from_hash(keys, hash, record_class)
    keys.map { |key| record_class.type_for_attribute(key.to_s).cast(hash[key]) }
  end

  def build_index_from_record(keys, record)
    keys.map { |key| record.send(key) }
  end

  def link_children_references(records)
    records.each do |rec|
      parent = records.detect { |r| r.manager_ref == rec.parent_ref } if rec.parent_ref.present?
      rec.update(:parent_id => parent.try(:id))
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

  def determine_deletes_using_association(ems, target)
    if target == ems
      :use_association
    else
      []
    end
  end

  def hashes_of_target_empty?(hashes, target)
    hashes.blank? || (hashes[:storages].blank? &&
    case target
    when VmOrTemplate
      hashes[:vms].blank?
    when Host
      hashes[:hosts].blank?
    when EmsFolder
      hashes[:folders].blank?
    end)
  end
end
