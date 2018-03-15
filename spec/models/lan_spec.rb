describe Lan do
  let(:lan) { FactoryGirl.create(:lan) }
  let!(:vm) { FactoryGirl.create(:vm_vmware, :hardware => FactoryGirl.create(:hardware, :guest_devices => [FactoryGirl.create(:guest_device_nic, :lan => lan)])) }
  let!(:template) { FactoryGirl.create(:template_vmware, :hardware => FactoryGirl.create(:hardware, :guest_devices => [FactoryGirl.create(:guest_device_nic, :lan => lan)])) }

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
