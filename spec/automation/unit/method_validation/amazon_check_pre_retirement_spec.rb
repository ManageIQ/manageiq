describe "amazon_check_pre_retirement Method Validation" do
  let(:user) do
    FactoryGirl.create(:user_with_group)
  end

  let(:method) do
    "/Cloud/VM/Retirement/StateMachines/Methods/CheckPreRetirement"
  end

  let(:method_url) do
    "#{method}?Vm::vm=#{vm.id}#amazon"
  end

  let(:ems) do
    FactoryGirl.create(:ems_vmware, :zone => zone)
  end

  let(:zone) do
    FactoryGirl.create(:zone)
  end

  let(:vm) do
    FactoryGirl.create(:vm_amazon, :ems_id => ems.id)
  end

  let(:ebs_hardware) do
    FactoryGirl.create(:hardware, :bitness             => 64,
                                  :virtualization_type => 'paravirtual',
                                  :root_device_type    => 'ebs')
  end

  let(:is_hardware) do
    FactoryGirl.create(:hardware, :bitness             => 64,
                                  :virtualization_type => 'paravirtual',
                                  :root_device_type    => 'instance-store')
  end

  let(:ws) do
    MiqAeEngine.instantiate(method_url, user)
  end

  it "instance-store instance ae_result should be ok" do
    vm.hardware = is_hardware
    vm.update_attribute(:raw_power_state, "running")

    expect(ws.root['ae_result']).to eq("ok")
  end

  it "ebs instance ae_result should be retry" do
    vm.hardware = ebs_hardware
    vm.update_attribute(:raw_power_state, "running")

    expect(ws.root['ae_result']).to eq("retry")
  end
end
