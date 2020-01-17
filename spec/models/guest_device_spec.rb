RSpec.describe GuestDevice do
  let!(:vm_gd) { FactoryBot.create(:guest_device_nic) }
  let!(:vm) { FactoryBot.create(:vm_vmware, :hardware => FactoryBot.create(:hardware, :guest_devices => [vm_gd])) }

  let!(:template_gd) { FactoryBot.create(:guest_device_nic) }
  let!(:template) { FactoryBot.create(:template_vmware, :hardware => FactoryBot.create(:hardware, :guest_devices => [template_gd])) }

  let!(:host_gd) { FactoryBot.create(:guest_device_nic) }
  let!(:host) { FactoryBot.create(:host, :hardware => FactoryBot.create(:hardware, :guest_devices => [host_gd])) }

  it "#vm_or_template" do
    expect(vm_gd.vm_or_template).to eq(vm)
    expect(template_gd.vm_or_template).to eq(template)
    expect(host_gd.vm_or_template).to     be_nil
  end

  it "#vm" do
    expect(vm_gd.vm).to eq(vm)
    expect(template_gd.vm).to be_nil
    expect(host_gd.vm).to     be_nil
  end

  it "#miq_template" do
    expect(vm_gd.miq_template).to       be_nil
    expect(template_gd.miq_template).to eq(template)
    expect(host_gd.miq_template).to     be_nil
  end

  it "#host" do
    expect(vm_gd.host).to       be_nil
    expect(template_gd.host).to be_nil
    expect(host_gd.host).to eq(host)
  end
end
