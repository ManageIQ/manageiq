class ManageIQ::Providers::<%= class_name %>::Inventory::Collector::CloudManager < ManageIQ::Providers::Inventory::Collector
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
