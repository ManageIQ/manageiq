describe EmsPhysicalInfra do
  it ".types" do
    expected_types = [ManageIQ::Providers::Lenovo::PhysicalInfraManager].collect(&:ems_type)
    expect(described_class.types).to match_array(expected_types)
  end

  it ".supported_subclasses" do
    expected_subclasses = [ManageIQ::Providers::Lenovo::PhysicalInfraManager]
    expect(described_class.supported_subclasses).to match_array(expected_subclasses)
  end

  it ".supported_types" do
    expected_types = [ManageIQ::Providers::Lenovo::PhysicalInfraManager].collect(&:ems_type)
    expect(described_class.supported_types).to match_array(expected_types)
  end
end
