module EmsRefresh::SaveInventoryHelper
  def save_inventory_multi(type, parent, hashes, deletes, find_key, child_keys = [], extra_keys = [], store_ref = false)
    deletes = deletes.to_a # make sure to load the association if it's an association
    child_keys, extra_keys, remove_keys = self.save_inventory_prep(child_keys, extra_keys)

    record_index, record_index_columns = self.save_inventory_prep_record_index(parent.send(type), find_key)

    new_records = []
    hashes.each do |h|
      found = save_inventory_with_findkey(type, parent, h.except(*remove_keys), deletes, new_records, record_index, record_index_columns, find_key)
      save_child_inventory(found, h, child_keys)
      h[:ar_object] = found if store_ref
    end

    # Delete the items no longer found
    unless deletes.blank?
      $log.info("MIQ(#{self.name}.save_#{type}_inventory) Deleting #{self.log_format_deletes(deletes)}")
      parent.send(type).delete(deletes)
    end

    # Add the new items
    parent.send(type).push(new_records)
  end

  def save_inventory_single(type, parent, hash, child_keys = [], extra_keys = [])
    child_keys, extra_keys, remove_keys = self.save_inventory_prep(child_keys, extra_keys)
    save_inventory(type, parent, hash.except(*remove_keys))
    save_child_inventory(parent.send(type), hash, child_keys)
  end

  def save_inventory_prep(child_keys, extra_keys)
    # Normalize the keys for different types on inputs
    child_keys = [child_keys].compact unless child_keys.kind_of?(Array)
    extra_keys = [extra_keys].compact unless extra_keys.kind_of?(Array)
    remove_keys = child_keys + extra_keys
    return child_keys, extra_keys, remove_keys
  end

  def save_inventory(type, parent, hash)
    # Find the record, and update if found, else create it
    found = parent.send(type)
    if found.nil?
      found = parent.send("build_#{type}", hash.except(:id))
      parent.send("#{type}=", found)
    else
      found.update_attributes!(hash.except(:id, :type))
    end
    found
  end

  def save_inventory_with_findkey(type, parent, hash, deletes, new_records, record_index, record_index_columns, find_key)
    # Find the record, and update if found, else create it
    found = save_inventory_record_index_fetch(record_index, record_index_columns, hash, find_key)
    if found.nil?
      found = parent.send(type).build(hash.except(:id))
      new_records << found
    else
      found.update_attributes!(hash.except(:id, :type))
      deletes.delete(found) unless deletes.blank?
    end
    found
  end

  def save_inventory_prep_record_index(records, find_key)
    # Save the columns associated with the find keys, so we can coerce the
    #   hash values during save_inventory_record_index_fetch
    columns_hash = records.first.try(:class).try(:columns_hash_with_virtual)
    record_index_columns = columns_hash.nil? ? [] : find_key.collect { |k| columns_hash[k.to_s] }

    # Index the records by the values from the find_key
    record_index = records.each_with_object({}) do |r, h|
      h.store_path(find_key.collect { |k| r.send(k) }, r)
    end

    return record_index, record_index_columns
  end

  def save_inventory_record_index_fetch(record_index, record_index_columns, hash, find_key)
    return nil if record_index.blank?

    hash_values = find_key.collect { |k| hash[k] }

    # Coerce each hash value into the db column type for valid lookup during fetch_path
    coerced_hash_values = hash_values.zip(record_index_columns).collect do |value, column|
      new_value = column.type_cast(value)
      new_value = new_value.to_s if column.text? && !new_value.nil? # type_cast doesn't actually convert string or text
      new_value
    end

    record_index.fetch_path(coerced_hash_values)
  end

  def backup_keys(hash, keys)
    keys.each_with_object({}) { |k, backup| backup[k] = hash.delete(k) if hash.has_key?(k) }
  end

  def restore_keys(hash, keys, backup)
    keys.each { |k| hash[k] = backup.delete(k) if backup.has_key?(k) }
  end

  def save_child_inventory(obj, hashes, child_keys, *args)
    child_keys.each { |k| send("save_#{k}_inventory", obj, hashes[k], *args) if hashes.key?(k) }
  end

  def store_ids_for_new_records(records, hashes, keys)
    keys = Array(keys)
    hashes.each do |h|
      r = records.detect { |r| keys.all? { |k| r.send(k) == h[k] } }
      h[:id] = r.id
    end
  end

  # most of the refresh_inventory_multi calls follow the same pattern
  # this pulls it out
  def save_inventory_assoc(type, parent, hashes, target, find_key, child_keys = [], extra_keys = [])
    deletes = relation_values(parent, type, target)

    save_inventory_multi(type, parent, hashes, deletes, find_key, child_keys, extra_keys, true)
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
  def relation_values(parent, type, target)
    # always want to refresh this association
    reflection = parent.class.reflect_on_association(type)
    # if this association isn't the definitive source
    top_level = reflection.options[:dependent] == :destroy

    top_level && (target == true || target.nil? || parent == target) ? parent.send(reflection.name).to_a.dup : []
  end
end
