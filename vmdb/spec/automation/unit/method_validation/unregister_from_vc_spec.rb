require File.expand_path(File.join(File.dirname(__FILE__), '..', '..',
'..', 'spec_helper'))

describe "unregister_from_vc Method Validation" do

  before(:each) do
    @zone       = FactoryGirl.create(:zone)
    @ems        = FactoryGirl.create(:ems_vmware, :zone => @zone)
    @host       = FactoryGirl.create(:host)
    @vm         = FactoryGirl.create(:vm_vmware, :host =>@host,
                 :ems_id => @ems.id, :name => "testVM", :state => "on",
                 :registered => true)
  end

  it "unregisters a vm" do
    ws = MiqAeEngine.instantiate(
    "/Factory/VM/UnregisterFromVC?Vm::vm=#{@vm.id}")

    MiqQueue.exists?(:method_name => 'unregister', :instance_id => @vm.id,
    :role => 'ems_operations').should be_true
  end

  it "errors for a vm equal to nil" do
    lambda{
      MiqAeEngine.instantiate("/Factory/VM/UnregisterFromVC?Vm::vm=#{nil}")
    }.should raise_error
  end

end

