RSpec.describe ManageIQ::Providers::NetworkManager do
  let(:vms) { FactoryBot.create(:vm) }
  let(:template) { FactoryBot.create(:miq_template) }

  let(:parent) { FactoryBot.create(:ems_openstack, :vms => [vms], :miq_templates => [template]) }
  let(:child)  { parent.network_manager }

  it "delegates vms and templates to parent manager (ExtManagementSystem)" do
    expect(parent.id).not_to eq(child.id)

    [parent, child].each do |ems|
      expect(ems.vms).to match_array([vms])
      expect(ems.total_vms).to eq(1)
      expect(ems.miq_templates).to match_array([template])
      expect(ems.total_miq_templates).to eq(1)
      expect(ems.vms_and_templates).to match_array([vms, template])
      expect(ems.total_vms_and_templates).to eq(2)
    end
  end

  it "delegates orchestration stacks to parent manager" do
    os = parent.orchestration_stacks.create(:ems_ref => "1")

    expect(child.orchestration_stacks).to eq([os])
  end

  it "delegates vms and templates to parent manager (when no manager)" do
    ems = FactoryBot.create(:ems_openstack_network, :parent => nil)

    expect(ems.vms).to eq([])
    expect(ems.total_vms).to eq(0)
    expect(ems.miq_templates).to eq([])
    expect(ems.total_miq_templates).to eq(0)
    expect(ems.vms_and_templates).to eq([])
    expect(ems.total_vms_and_templates).to eq(0)
  end
end
