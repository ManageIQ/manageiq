class <%= class_name %>::Inventory::Collector < ManageIQ::Providers::Inventory::Collector
  require_nested :<%= manager_type %>

  def connection
    @connection ||= manager.connect
  end

  def vms
    connection.vms
  end
end
