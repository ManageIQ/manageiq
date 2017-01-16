describe ConfigurationScriptSource do
  let(:manager) { FactoryGirl.create(:configuration_manager_ansible_tower, :provider) }
  let(:configuration_script_source) { FactoryGirl.create(:configuration_script_source, :manager => manager) }
  let!(:payloads) do
    [FactoryGirl.create(:configuration_script_payload, :configuration_script_source => configuration_script_source),
     FactoryGirl.create(:configuration_script_payload, :configuration_script_source => configuration_script_source)]
  end

  it "belongs_to the Ansible Tower manager" do
    expect(configuration_script_source.manager).to eq(manager)
    expect(manager.configuration_script_sources.size).to eq 1
    expect(manager.configuration_script_sources.first).to be_a ConfigurationScriptSource
  end

  it "can have multiple configuration_script_payloads" do
    expect(configuration_script_source.configuration_script_payloads.size).to eq 2
    expect(payloads[0].configuration_script_source).to eq(configuration_script_source)
  end
end
