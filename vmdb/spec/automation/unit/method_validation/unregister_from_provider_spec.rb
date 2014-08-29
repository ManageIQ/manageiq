require File.expand_path(File.join(File.dirname(__FILE__), '..', '..',
'..', 'spec_helper'))

describe "unregister_from_provider Method Validation" do

  before(:each) do
    @zone       = FactoryGirl.create(:zone)
    @ems        = FactoryGirl.create(:ems_vmware, :zone => @zone)
    @host       = FactoryGirl.create(:host)
    @vm         = FactoryGirl.create(:vm_vmware, :host =>@host,
                 :ems_id => @ems.id, :name => "testVM", :state => "on",
                 :registered => true)
  end

  let(:ws) { MiqAeEngine.instantiate("/Infrastructure/VM/Retirement/StateMachines/Methods/UnregisterFromProvider?Vm::vm=#{@vm_id}") }

  it "unregisters a vm" do
    @vm_id = @vm.id

    ws

    MiqQueue.exists?(:method_name => 'unregister', :instance_id => @vm.id,
    :role => 'ems_operations').should be_true
  end

  it "errors for a vm equal to nil" do
    @vm_id = nil

    lambda { ws }.should raise_error
  end

end

