class <%= class_name %>::Inventory::Persister < ManageIQ::Providers::Inventory::Persister
  require_nested :<%= manager_type %>
end
