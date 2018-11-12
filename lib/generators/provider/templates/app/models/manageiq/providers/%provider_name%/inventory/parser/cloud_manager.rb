class ManageIQ::Providers::<%= class_name %>::Inventory::Parser::CloudManager < ManageIQ::Providers::Inventory::Parser
  def parse
    vms
  end

  def vms
    collector.vms.each do |inventory|
      inventory_object = persister.vms.find_or_build(inventory.id.to_s)
      inventory_object.name = inventory.name
      inventory_object.location = inventory.location
      inventory_object.vendor = inventory.vendor
    end
  end

end
