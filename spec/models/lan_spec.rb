describe Lan do
  before(:each) do
    @lan      = FactoryGirl.create(:lan)
    @vm       = FactoryGirl.create(:vm_vmware,       :hardware => FactoryGirl.create(:hardware, :guest_devices => [FactoryGirl.create(:guest_device_nic, :lan => @lan)]))
    @template = FactoryGirl.create(:template_vmware, :hardware => FactoryGirl.create(:hardware, :guest_devices => [FactoryGirl.create(:guest_device_nic, :lan => @lan)]))
  end

  it "#vms_and_templates" do
    expect(@lan.vms_and_templates).to match_array [@vm, @template]
  end

  it "#vms" do
    expect(@lan.vms).to eq([@vm])
  end

  it "#miq_templates" do
    expect(@lan.miq_templates).to eq([@template])
  end
end
