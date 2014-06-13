require File.expand_path(File.join(File.dirname(__FILE__), '..', '..',
'..', 'spec_helper'))

describe "power_off Method Validation" do

  before(:each) do
    @zone       = FactoryGirl.create(:zone)
    @ems        = FactoryGirl.create(:ems_vmware, :zone => @zone)
    @host       = FactoryGirl.create(:host)
    @vm         = FactoryGirl.create(:vm_vmware, :host =>@host,
                 :ems_id => @ems.id, :name => "testVM2", :state => "on")
  end

  it "powers off a vm in a 'powered on' state" do
    ws = MiqAeEngine.instantiate("/Factory/VM/PowerOff?Vm::vm=#{@vm.id}")

    MiqQueue.exists?(:method_name => 'stop', :instance_id => @vm.id,
    :role => 'ems_operations').should be_true
  end

  it "does not queue any operation for a vm in 'powered_off' state" do
    @vm.update_attribute(:state, "off")
    ws = MiqAeEngine.instantiate("/Factory/VM/PowerOff?Vm::vm=#{@vm.id}")

    MiqQueue.exists?(:method_name => 'stop', :instance_id => @vm.id,
    :role => 'ems_operations').should be_false
  end

end

