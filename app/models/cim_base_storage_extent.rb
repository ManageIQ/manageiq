class CimBaseStorageExtent < ActsAsArScope
  set_columns_hash(CimStorageExtent.columns_hash.keys.each_with_object({}) { |c, h| h[c.to_sym] = CimStorageExtent.columns_hash[c].type })

  def self.aar_scope
    CimStorageExtent.where(:id => base_storage_extent_ids)
  end

  # TODO: this is really inefficient. please fix
  def self.base_storage_extent_ids
    CimComputerSystem.all.collect(&:base_storage_extents).flatten.compact.uniq.collect(&:id)
  end
end
