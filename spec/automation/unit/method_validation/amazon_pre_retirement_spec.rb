describe "amazon_pre_retirement Method Validation" do
  before(:each) do
    @user = FactoryGirl.create(:user_with_group)
    @zone = FactoryGirl.create(:zone)
    @ems  = FactoryGirl.create(:ems_vmware, :zone => @zone)
    @ebs_hardware = FactoryGirl.create(:hardware, :bitness             => 64,
                                                  :virtualization_type => 'paravirtual',
                                                  :root_device_type    => 'ebs')
    @is_hardware  = FactoryGirl.create(:hardware, :bitness             => 64,
                                                  :virtualization_type => 'paravirtual',
                                                  :root_device_type    => 'instance_store')
    @vm   = FactoryGirl.create(:vm_amazon,
                               :name => "testVM", :raw_power_state => "running", :ems_id => @ems.id,
                               :registered => true)
    @ins  = "/Cloud/VM/Retirement/StateMachines/Methods/PreRetirement"
  end

  it "calls stop for ebs instances" do
    @vm.hardware = @ebs_hardware
    MiqAeEngine.instantiate("#{@ins}?Vm::vm=#{@vm.id}#amazon", @user)
    expect(MiqQueue.exists?(:method_name => 'stop', :instance_id => @vm.id, :role => 'ems_operations')).to be_truthy
  end

  it "should not call stop for instance store instances" do
    @vm.hardware = @is_hardware
    MiqAeEngine.instantiate("#{@ins}?Vm::vm=#{@vm.id}#amazon", @user)
    expect(MiqQueue.exists?(:method_name => 'stop', :instance_id => @vm.id, :role => 'ems_operations')).to be_falsey
  end
end
