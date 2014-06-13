require "spec_helper"

describe "VM Retirement Management" do
  before(:each) do
    @guid = MiqUUID.new_guid
    MiqServer.stub(:my_guid).and_return(@guid)

    @zone       = FactoryGirl.create(:zone)
    @miq_server = FactoryGirl.create(:miq_server, :guid => @guid, :zone => @zone)
    MiqServer.stub(:my_server).and_return(@miq_server)
    @ems        = FactoryGirl.create(:ems_vmware, :zone => @zone)
  end

  it ".retirement_check" do
    vm = FactoryGirl.create(:vm_vmware, :ems_id => @ems.id)
    MiqEvent.should_receive(:raise_evm_event)
    vm.update_attributes(:retires_on => 90.days.ago, :retirement_warn => 60, :retirement_last_warn => nil)
    vm.retirement_last_warn.should be_nil
    vm.class.any_instance.should_receive(:retire_now).once
    Vm.retirement_check
    vm.reload
    vm.retirement_last_warn.should_not be_nil
    (Time.now.utc - vm.retirement_last_warn).should be < 30
  end

  it "#retire_now" do
    vm = FactoryGirl.create(:vm_vmware, :ems_id => @ems.id)
    vm.should_receive(:before_retirement)
    vm.should_receive(:raise_audit_event)
    vm.should_receive(:raise_retirement_event)
    vm.retire_now
    vm.retires_on.should == Date.today
    vm.retired.should be_true
  end

  it "#retirement_due?" do
    vm = FactoryGirl.create(:vm_vmware, :ems_id => @ems.id)
    vm.retirement_due?.should be_false

    vm.retires_on = Date.today + 1.day
    vm.save!
    vm.retirement_due?.should be_false

    vm.retires_on = Date.today
    vm.save!
    vm.retirement_due?.should be_true

    vm.retires_on = Date.today - 1.day
    vm.save!
    vm.retirement_due?.should be_true
  end

  it "#raise_retirement_event" do
    event_name = 'foo'
    vm = FactoryGirl.create(:vm_vmware)
    event_hash = { :vm => vm, :host => vm.host }
    MiqEvent.should_receive(:raise_evm_event).with(vm, event_name, event_hash)
    vm.raise_retirement_event(event_name)
  end

  it "#raise_audit_event" do
    event_name = 'foo'
    message = 'bar'
    vm = FactoryGirl.create(:vm_vmware)
    event_hash = { :target_class => "Vm", :target_id => vm.id.to_s, :event => event_name, :message => message }
    AuditEvent.should_receive(:success).with(event_hash)
    vm.raise_audit_event(event_name, message)
  end

end
