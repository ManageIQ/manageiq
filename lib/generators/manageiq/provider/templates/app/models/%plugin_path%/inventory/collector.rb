class <%= class_name %>::Inventory::Collector < ManageIQ::Providers::Inventory::Collector
  require_nested :<%= manager_type %>

  def connection
    @connection ||= manager.connect
  end

  def vms
    [
      OpenStruct.new(:id => '1', :name => 'funky', :location => 'dc-1', :vendor => 'unknown'),
      OpenStruct.new(:id => '2', :name => 'bunch', :location => 'dc-1', :vendor => 'unknown')
    ]
  end
end
