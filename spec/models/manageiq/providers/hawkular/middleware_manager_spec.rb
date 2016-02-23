describe ManageIQ::Providers::Hawkular::MiddlewareManager do
  it ".ems_type" do
    expect(described_class.ems_type).to eq('hawkular')
  end

  it ".description" do
    expect(described_class.description).to eq('Hawkular')
  end
end
