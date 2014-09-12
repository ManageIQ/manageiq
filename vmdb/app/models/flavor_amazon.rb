class FlavorAmazon < Flavor
  virtual_column :supports_instance_store, :type => :boolean
  virtual_column :supports_ebs,            :type => :boolean

  def supports_instance_store?
    !block_storage_based_only?
  end

  def supports_ebs?
    block_storage_based_only?
  end
end
