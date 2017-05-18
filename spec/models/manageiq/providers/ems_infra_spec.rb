describe EmsInfra do
  it ".types" do
    expected_types = [ManageIQ::Providers::Vmware::InfraManager,
                      ManageIQ::Providers::Redhat::InfraManager,
                      ManageIQ::Providers::Microsoft::InfraManager,
                      ManageIQ::Providers::Openstack::InfraManager].collect(&:ems_type)
    expect(described_class.types).to match_array(expected_types)
  end

  it ".supported_subclasses" do
    expected_subclasses = [ManageIQ::Providers::Vmware::InfraManager,
                           ManageIQ::Providers::Microsoft::InfraManager,
                           ManageIQ::Providers::Redhat::InfraManager,
                           ManageIQ::Providers::Openstack::InfraManager]
    expect(described_class.supported_subclasses).to match_array(expected_subclasses)
  end

  it ".supported_types" do
    expected_types = [ManageIQ::Providers::Vmware::InfraManager,
                      ManageIQ::Providers::Microsoft::InfraManager,
                      ManageIQ::Providers::Redhat::InfraManager,
                      ManageIQ::Providers::Openstack::InfraManager].collect(&:ems_type)
    expect(described_class.supported_types).to match_array(expected_types)
  end
end
