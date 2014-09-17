require File.expand_path(File.join(File.dirname(__FILE__), '..', '..',
'..', 'spec_helper'))

describe "check_unregistered_from_provider Method Validation" do

  before(:each) do
    @zone       = FactoryGirl.create(:zone)
    @ems        = FactoryGirl.create(:ems_vmware, :zone => @zone)
    @host       = FactoryGirl.create(:host)
    @vm         = FactoryGirl.create(:vm_vmware,
                 :name => "testVM", :raw_power_state => "poweredOff",
                 :registered => false)
  end

  let(:ws) { MiqAeEngine.instantiate("/Infrastructure/VM/Retirement/StateMachines/Methods/CheckUnregisteredFromProvider?Vm::vm=#{@vm.id}") }

  it "returns 'ok' if the vm is unregisted" do
    ws.root['vm']['registered'].should  == false
    ws.root['ae_result'].should         == "ok"
  end

  it "retires for a vm that is registered" do
    @vm.update_attributes(:host =>@host,
                 :ems_id => @ems.id,
                 :registered => true)

    ws.root['ae_result'].should         == "retry"
    ws.root['vm']['registered'].should  == true
  end

end
