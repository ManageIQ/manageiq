module SpecParsedData
  def vm_data(i, data = {})
    {
      :type            => ManageIQ::Providers::CloudManager::Vm.name,
      :uid_ems         => "vm_uid_ems_#{i}",
      :ems_ref         => "vm_ems_ref_#{i}",
      :name            => "vm_name_#{i}",
      :vendor          => "amazon",
      :raw_power_state => "unknown",
      :location        => "vm_location_#{i}",
    }.merge(data)
  end
end
