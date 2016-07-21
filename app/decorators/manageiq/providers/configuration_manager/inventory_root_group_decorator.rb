class ManageIQ::Providers::ConfigurationManager::InventoryRootGroupDecorator < Draper::Decorator
  delegate_all

  def fonticon
    nil
  end

  def listicon_image
    '100/inventory_group.png'
  end
end
