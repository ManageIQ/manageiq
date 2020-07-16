class <%= class_name %>::Inventory::Collector < ManageIQ::Providers::Inventory::Collector
  require_nested :<%= manager_type %>
end
