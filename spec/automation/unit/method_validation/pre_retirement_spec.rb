require File.expand_path(File.join(File.dirname(__FILE__), '..', '..',
                                   '..', 'spec_helper'))
def run_automate_method
  MiqAeEngine.instantiate("/Infrastructure/VM/Retirement/StateMachines/Methods/PreRetirement?" \
                          "Vm::vm=#{@vm.id}#microsoft", @user)
end

describe "pre_retirement Method Validation" do
  before(:each) do
    @zone       = FactoryGirl.create(:zone)
    @user       = FactoryGirl.create(:user_with_group)
    @ems        = FactoryGirl.create(:ems_microsoft, :zone => @zone)
    @host       = FactoryGirl.create(:host)
    @vm         = FactoryGirl.create(:vm_microsoft, :host => @host,
                 :ems_id => @ems.id, :name => "testVM2", :raw_power_state => "poweredOn")
  end

  it "powers off a vm in a 'powered on' state" do
    run_automate_method

    expect(MiqQueue.exists?(:method_name => 'stop', :instance_id => @vm.id, :role => 'ems_operations')).to be_truthy
  end

  it "does not queue any operation for a vm in 'powered_off' state" do
    @vm.update_attribute(:raw_power_state, "PowerOff")
    run_automate_method

    expect(MiqQueue.exists?(:method_name => 'stop', :instance_id => @vm.id, :role => 'ems_operations')).to be_falsey
  end
end
