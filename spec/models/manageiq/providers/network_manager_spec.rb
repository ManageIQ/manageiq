describe ManageIQ::Providers::NetworkManager do
  let(:vms) { FactoryBot.create(:vm) }
  let(:template) { FactoryBot.create(:miq_template) }

  let(:ems) { FactoryBot.create(:ems_openstack, :vms => [vms], :miq_templates => [template]) }

  it "delegates vms and templates to parent manager (ExtManagementSystem)" do
    expect(ems.id).not_to eq(ems.network_manager.id)
    expect(ems.vms).to match_array([vms])
    expect(ems.network_manager.vms).to match_array([vms])
    expect(ems.miq_templates).to match_array([template])
    expect(ems.network_manager.miq_templates).to match_array([template])
    expect(ems.vms_and_templates).to match_array([vms, template])
    expect(ems.network_manager.vms_and_templates).to match_array([vms, template])
  end
end
