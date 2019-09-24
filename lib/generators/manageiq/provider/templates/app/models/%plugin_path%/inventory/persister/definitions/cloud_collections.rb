module <%= class_name %>::Inventory::Persister::Definitions::CloudCollections
  extend ActiveSupport::Concern

  def initialize_cloud_inventory_collections
    %i(vms).each do |name|
      add_collection(cloud, name)
    end
  end
end
