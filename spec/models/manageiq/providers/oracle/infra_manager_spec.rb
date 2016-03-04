describe ManageIQ::Providers::Oracle::InfraManager do
  it ".ems_type" do
    expect(described_class.ems_type).to eq('oraclevm')
  end

  it ".description" do
    expect(described_class.description).to eq('Oracle Virtualization Manager')
  end
end
