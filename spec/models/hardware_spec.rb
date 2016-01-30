describe Hardware do
  before(:each) do
    @vm_hw = FactoryGirl.create(:hardware)
    @vm    = FactoryGirl.create(:vm_vmware, :hardware => @vm_hw)

    @template_hw = FactoryGirl.create(:hardware)
    @template    = FactoryGirl.create(:template_vmware, :hardware => @template_hw)

    @host_hw = FactoryGirl.create(:hardware)
    @host    = FactoryGirl.create(:host, :hardware => @host_hw)
  end

  it "#vm_or_template" do
    expect(@vm_hw.vm_or_template).to eq(@vm)
    expect(@template_hw.vm_or_template).to eq(@template)
    expect(@host_hw.vm_or_template).to     be_nil
  end

  it "#vm" do
    expect(@vm_hw.vm).to eq(@vm)
    expect(@template_hw.vm).to be_nil
    expect(@host_hw.vm).to     be_nil
  end

  it "#miq_template" do
    expect(@vm_hw.miq_template).to       be_nil
    expect(@template_hw.miq_template).to eq(@template)
    expect(@host_hw.miq_template).to     be_nil
  end

  it "#host" do
    expect(@vm_hw.host).to       be_nil
    expect(@template_hw.host).to be_nil
    expect(@host_hw.host).to eq(@host)
  end
end
