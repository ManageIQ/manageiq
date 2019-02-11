class ManageIQ::Providers::EmbeddedAnsible::Inventory < ManageIQ::Providers::Inventory
  require_nested :Collector
  require_nested :Parser
  require_nested :Persister

  def self.default_manager_name
    "AutomationManager"
  end

  def self.parser_classes_for(ems, target)
    case target
    when InventoryRefresh::TargetCollection
      [ManageIQ::Providers::EmbeddedAnsible::Inventory::Parser::AutomationManager]
    else
      super
    end
  end
end
