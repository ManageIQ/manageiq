class <%= class_name %>::Inventory::Parser < ManageIQ::Providers::Inventory::Parser
  require_nested :<%= manager_type %>
end
