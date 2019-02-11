class ManageIQ::Providers::EmbeddedAnsible::Inventory::Collector < ManageIQ::Providers::Inventory::Collector
  require_nested :AutomationManager
  require_nested :TargetCollection
end
