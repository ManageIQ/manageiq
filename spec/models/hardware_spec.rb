describe Hardware do
  let(:vm) { FactoryGirl.create(:vm_vmware, :hardware => FactoryGirl.create(:hardware)) }
  let(:template) { FactoryGirl.create(:template_vmware, :hardware => FactoryGirl.create(:hardware)) }
  let(:host) { FactoryGirl.create(:host, :hardware => FactoryGirl.create(:hardware)) }

  it "#vm_or_template" do
    expect(vm.hardware.vm_or_template).to eq(vm)
    expect(template.hardware.vm_or_template).to eq(template)
    expect(host.hardware.vm_or_template).to     be_nil
  end

  it "#vm" do
    expect(vm.hardware.vm).to eq(vm)
    expect(template.hardware.vm).to be_nil
    expect(host.hardware.vm).to     be_nil
  end

  it "#miq_template" do
    expect(vm.hardware.miq_template).to       be_nil
    expect(template.hardware.miq_template).to eq(template)
    expect(host.hardware.miq_template).to     be_nil
  end

  it "#host" do
    expect(vm.hardware.host).to       be_nil
    expect(template.hardware.host).to be_nil
    expect(host.hardware.host).to eq(host)
  end
end
