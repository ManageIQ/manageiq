describe "amazon_check_pre_retirement Method Validation" do
  before(:each) do
    @zone = FactoryGirl.create(:zone)
    @user = FactoryGirl.create(:user_with_group)
    @ems  = FactoryGirl.create(:ems_amazon, :zone => @zone)
    @ebs_hardware = FactoryGirl.create(:hardware, :bitness             => 64,
                                                  :virtualization_type => 'paravirtual',
                                                  :root_device_type    => 'ebs')
    @is_hardware  = FactoryGirl.create(:hardware, :bitness             => 64,
                                                  :virtualization_type => 'paravirtual',
                                                  :root_device_type    => 'instance-store')
    @vm   = FactoryGirl.create(:vm_amazon,
                               :name => "AMZN",    :raw_power_state => "running",
                               :ems_id => @ems.id, :registered => true)
    @ins  = "/Cloud/VM/Retirement/StateMachines/Methods/CheckPreRetirement"
  end

  it "returns 'ok' for instance store instances even with power on" do
    @vm.hardware = @is_hardware
    ws = MiqAeEngine.instantiate("#{@ins}?Vm::vm=#{@vm.id}#amazon", @user)
    expect(ws.root['ae_result']).to eq('ok')
    expect(ws.root['vm'].power_state).to eq('on')
  end

  it "returns 'retry' for running ebs instances" do
    expect_any_instance_of(Vm).to receive(:refresh_ems).and_return({})
    @vm.hardware = @ebs_hardware
    ws = MiqAeEngine.instantiate("#{@ins}?Vm::vm=#{@vm.id}#amazon", @user)
    expect(ws.root['ae_result']).to eq('retry')
    expect(ws.root['vm'].power_state).to eq('on')
  end

  it "returns 'ok' for stopped ebs instances" do
    @vm.hardware = @ebs_hardware
    @vm.update_attributes(:raw_power_state => "off")
    ws = MiqAeEngine.instantiate("#{@ins}?Vm::vm=#{@vm.id}#amazon", @user)
    expect(ws.root['ae_result']).to eq('ok')
    expect(ws.root['vm'].power_state).to eq('off')
  end

  it "returns 'ok' for ebs instance with unknown power state" do
    @vm.hardware = @ebs_hardware
    @vm.update_attributes(:raw_power_state => "unknown")
    ws = MiqAeEngine.instantiate("#{@ins}?Vm::vm=#{@vm.id}#amazon", @user)
    expect(ws.root['ae_result']).to eq('ok')
    expect(ws.root['vm'].power_state).to eq('terminated')
  end
end
