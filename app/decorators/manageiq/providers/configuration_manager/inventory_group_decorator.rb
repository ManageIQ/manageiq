class ManageIQ::Providers::ConfigurationManager::InventoryGroupDecorator < Draper::Decorator
  delegate_all

  def fonticon
    'pficon pficon-folder-close'.freeze
  end
end
