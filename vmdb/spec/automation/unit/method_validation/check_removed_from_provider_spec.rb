require 'spec_helper'

describe "check_removed_from_provider Method Validation" do
  before(:each) do
    @zone = FactoryGirl.create(:zone)
    @ems  = FactoryGirl.create(:ems_vmware, :zone => @zone)
    @host = FactoryGirl.create(:host)
    @vm   = FactoryGirl.create(:vm_vmware,
                               :name => "testVM", :raw_power_state => "poweredOff",
                               :registered => false)
    @ae_state   = {'vm_removed_from_provider' => true}
    @ins  = "/Infrastructure/VM/Retirement/StateMachines/Methods/CheckRemovedFromProvider"
  end

  let(:ws) { MiqAeEngine.instantiate("#{@ins}?Vm::vm=#{@vm.id}&ae_state_data=#{URI.escape(YAML.dump(@ae_state))}") }

  it "returns 'ok' if the vm is not connected to a ems" do
    ws.root['vm']['registered'].should  eql(false)
    ws.root['ae_result'].should         eql("ok")
  end

  it "returns 'retry' if the vm is still connected to ems" do
    @vm.update_attributes(:host => @host, :ems_id => @ems.id,
                          :registered => true)

    ws.root['ae_result'].should         eql("retry")
    ws.root['vm']['registered'].should  == true
  end
end
