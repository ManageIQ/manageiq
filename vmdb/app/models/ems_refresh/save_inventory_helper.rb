module EmsRefresh::SaveInventoryHelper
  def save_inventory_multi(type, klass, parent, hashes, deletes, find_key, child_keys = [], extra_keys = [])
    find_key, child_keys, extra_keys, remove_keys = self.save_inventory_prep(find_key, child_keys, extra_keys)
    record_index, record_index_columns = self.save_inventory_prep_record_index(parent.send(type), find_key)

    new_records = []
    hashes.each do |h|
      self.save_inventory(type, klass, parent, h, deletes, new_records, record_index, record_index_columns, find_key, child_keys, remove_keys)
    end

    # Delete the items no longer found
    unless deletes.blank?
      $log.info("MIQ(#{self.name}.save_#{type}_inventory) Deleting #{self.log_format_deletes(deletes)}")
      parent.send(type).delete(deletes)
    end

    # Add the new items
    parent.send(type).push(new_records)
  end

  def save_inventory_single(type, klass, parent, hash, child_keys = [], extra_keys = [])
    find_key, child_keys, extra_keys, remove_keys = self.save_inventory_prep(nil, child_keys, extra_keys)
    self.save_inventory(type, klass, parent, hash, nil, nil, nil, nil, nil, child_keys, remove_keys)
  end

  def save_inventory_prep(find_key, child_keys, extra_keys)
    # Normalize the keys for different types on inputs
    find_key = [find_key].compact unless find_key.kind_of?(Array)
    child_keys = [child_keys].compact unless child_keys.kind_of?(Array)
    extra_keys = [extra_keys].compact unless extra_keys.kind_of?(Array)
    remove_keys = child_keys + extra_keys
    return find_key, child_keys, extra_keys, remove_keys
  end

  def save_inventory(type, klass, parent, hash, deletes, new_records, record_index, record_index_columns, find_key, child_keys, remove_keys)
    # Backup keys that cannot be written directly to the database
    key_backup = backup_keys(hash, remove_keys)

    # Find the record, and update if found, else create it
    found = find_key.blank? ? parent.send(type) : self.save_inventory_record_index_fetch(record_index, record_index_columns, hash, find_key)
    if found.nil?
      found = klass.new(hash)
      new_records.nil? ? parent.send("#{type}=", found) : new_records << found
    else
      key_backup.merge!(backup_keys(hash, [:type]))
      found.update_attributes!(hash)
      deletes.delete(found) unless deletes.blank?
    end

    save_child_inventory(found, key_backup, child_keys)
    restore_keys(hash, remove_keys, key_backup)
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

  # most of the refresh_multi calls follow the same pattern
  # this pulls it out
  def save_inventory_assoc(type, parent, hashes, target, find_key, child_keys = [], extra_keys = [])
    reflection = parent.reflections[type]
    klass = reflection.class_name.constantize
    deletes = relation_values(parent, reflection, target)

    save_inventory_multi(type, klass, parent, hashes, deletes, find_key, child_keys, extra_keys)
    store_ids_for_new_records(parent.send(type), hashes, find_key)
  end

  # We need to determine our intent:
  # - make a complete refresh. Delete missing values.
  # - make a partial refresh. Don't delete missing keys
  # This generates the "deletes" values based upon this intent
  def relation_values(parent, reflection, target)
    # always want to refresh this association
    reflection = parent.reflections[reflection] if reflection.kind_of?(Symbol)
    values = parent.send(reflection.name, true)
    top_level = reflection.options[:dependent] == :destroy

    top_level && (target == true || target.nil? || parent == target) ? values.dup : []
  end
end
