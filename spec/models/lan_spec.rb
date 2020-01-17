RSpec.describe Lan do
  let(:lan) { FactoryBot.create(:lan) }
  let!(:vm) { FactoryBot.create(:vm_vmware, :hardware => FactoryBot.create(:hardware, :guest_devices => [FactoryBot.create(:guest_device_nic, :lan => lan)])) }
  let!(:template) { FactoryBot.create(:template_vmware, :hardware => FactoryBot.create(:hardware, :guest_devices => [FactoryBot.create(:guest_device_nic, :lan => lan)])) }

  it "#vms_and_templates" do
    expect(lan.vms_and_templates).to match_array [vm, template]
  end

  it "#vms" do
    expect(lan.vms).to eq([vm])
  end

  it "#miq_templates" do
    expect(lan.miq_templates).to eq([template])
  end
end
