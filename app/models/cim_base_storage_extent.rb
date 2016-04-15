class CimBaseStorageExtent < ActsAsArModel
  set_columns_hash(CimStorageExtent.columns_hash.keys.each_with_object({}) { |c, h| h[c.to_sym] = CimStorageExtent.columns_hash[c].type })

  def self._virtual_columns_hash
    CimStorageExtent._virtual_columns_hash
  end

  def self._virtual_reflections
    CimStorageExtent._virtual_reflections
  end

  def self.aar_scope
    CimStorageExtent.where(:id => base_storage_extent_ids)
  end

  def self.base_storage_extent_ids
    CimComputerSystem.all.collect(&:base_storage_extents).flatten.compact.uniq.collect(&:id)
  end

  def self.reflections
    CimStorageExtent.reflections
  end

  def self.table_name
    CimStorageExtent.table_name
  end
end
