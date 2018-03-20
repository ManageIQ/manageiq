describe GuestDevice do
  before do
    @vm_gd = FactoryGirl.create(:guest_device_nic)
    @vm    = FactoryGirl.create(:vm_vmware, :hardware => FactoryGirl.create(:hardware, :guest_devices => [@vm_gd]))

    @template_gd = FactoryGirl.create(:guest_device_nic)
    @template    = FactoryGirl.create(:template_vmware, :hardware => FactoryGirl.create(:hardware, :guest_devices => [@template_gd]))

    @host_gd = FactoryGirl.create(:guest_device_nic)
    @host    = FactoryGirl.create(:host, :hardware => FactoryGirl.create(:hardware, :guest_devices => [@host_gd]))
  end

  it "#vm_or_template" do
    expect(@vm_gd.vm_or_template).to eq(@vm)
    expect(@template_gd.vm_or_template).to eq(@template)
    expect(@host_gd.vm_or_template).to     be_nil
  end

  it "#vm" do
    expect(@vm_gd.vm).to eq(@vm)
    expect(@template_gd.vm).to be_nil
    expect(@host_gd.vm).to     be_nil
  end

  it "#miq_template" do
    expect(@vm_gd.miq_template).to       be_nil
    expect(@template_gd.miq_template).to eq(@template)
    expect(@host_gd.miq_template).to     be_nil
  end

  it "#host" do
    expect(@vm_gd.host).to       be_nil
    expect(@template_gd.host).to be_nil
    expect(@host_gd.host).to eq(@host)
  end
end
