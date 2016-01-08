require File.expand_path(File.join(File.dirname(__FILE__), '..', '..',
                                   '..', 'spec_helper'))

describe "unregister_from_provider Method Validation" do
  before(:each) do
    @zone       = FactoryGirl.create(:zone)
    @user       = FactoryGirl.create(:user_with_group)
    @ems        = FactoryGirl.create(:ems_vmware, :zone => @zone)
    @host       = FactoryGirl.create(:host)
    @vm         = FactoryGirl.create(:vm_vmware, :host => @host,
                 :ems_id => @ems.id, :name => "testVM", :raw_power_state => "poweredOn",
                 :registered => true)
  end

  let(:ws) { MiqAeEngine.instantiate("/Infrastructure/VM/Retirement/StateMachines/Methods/UnregisterFromProvider?Vm::vm=#{@vm_id}", @user) }

  it "unregisters a vm" do
    @vm_id = @vm.id

    ws

    expect(MiqQueue.exists?(:method_name => 'unregister', :instance_id => @vm.id,
    :role => 'ems_operations')).to be_truthy
  end

  it "errors for a vm equal to nil" do
    @vm_id = nil

    expect { ws }.to raise_error(MiqAeException::UnknownMethodRc)
  end
end
