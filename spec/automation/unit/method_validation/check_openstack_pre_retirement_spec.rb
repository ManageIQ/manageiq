describe "openstack_check_pre_retirement Method Validation" do
  before(:each) do
    @zone = FactoryGirl.create(:zone)
    @user = FactoryGirl.create(:user_with_group)
    @ems  = FactoryGirl.create(:ems_vmware, :zone => @zone)
    @vm   = FactoryGirl.create(:vm_openstack,
                               :name => "OOO",     :raw_power_state => "ACTIVE",
                               :ems_id => @ems.id, :registered => true)
    @ins  = "/Cloud/VM/Retirement/StateMachines/Methods/CheckPreRetirement"
  end

  it "returns 'retry' for running instances" do
    ws = MiqAeEngine.instantiate("#{@ins}?Vm::vm=#{@vm.id}#openstack", @user)
    expect(ws.root['ae_result']).to eq('retry')
    expect(ws.root['vm'].power_state).to eq('on')
  end

  it "returns 'ok' for stopped instances" do
    @vm.update_attributes(:raw_power_state => "SHUTOFF")
    ws = MiqAeEngine.instantiate("#{@ins}?Vm::vm=#{@vm.id}#openstack", @user)
    expect(ws.root['ae_result']).to eq('ok')
    expect(ws.root['vm'].power_state).to eq('off')
  end
end
