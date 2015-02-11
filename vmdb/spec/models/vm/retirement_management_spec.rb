require "spec_helper"

describe "VM Retirement Management" do
  before(:each) do
    @guid = MiqUUID.new_guid
    MiqServer.stub(:my_guid).and_return(@guid)

    @zone       = FactoryGirl.create(:zone)
    @miq_server = FactoryGirl.create(:miq_server, :guid => @guid, :zone => @zone)
    MiqServer.stub(:my_server).and_return(@miq_server)
    @ems        = FactoryGirl.create(:ems_vmware, :zone => @zone)
    @vm = FactoryGirl.create(:vm_vmware, :ems_id => @ems.id)
  end

  it "#retirement_check" do
    expect(MiqAeEvent).to receive(:raise_evm_event).once
    @vm.update_attributes(:retires_on => 90.days.ago, :retirement_warn => 60, :retirement_last_warn => nil)
    expect(@vm.retirement_last_warn).to be_nil
    @vm.class.any_instance.should_receive(:retire_now).once
    @vm.retirement_check
    @vm.reload
    expect(@vm.retirement_last_warn).not_to be_nil
    expect(Time.now.utc - @vm.retirement_last_warn).to be < 30
  end

  it "#start_retirement" do
    expect(@vm.retirement_state).to be_nil
    @vm.start_retirement
    @vm.reload

    expect(@vm.retirement_state).to eq("retiring")
  end

  it "#retire_now" do
    expect(MiqAeEvent).to receive(:raise_evm_event).once

    @vm.retire_now
  end

  it "#finish_retirement" do
    expect(@vm.retirement_state).to be_nil
    @vm.finish_retirement
    @vm.reload

    expect(@vm.retired).to eq(true)
    expect(@vm.retires_on).to eq(Date.today)
    expect(@vm.retirement_state).to eq("retired")
  end

  it "#is_or_being_retired - false" do
    expect(@vm.retirement_state).to be_nil
    expect(@vm.is_or_being_retired?).to be_false
  end

  it "#is_or_being_retired - true" do
    @vm.update_attributes(:retirement_state => 'retiring')

    expect(@vm.is_or_being_retired?).to be_true
  end

  it "#retires_on - today" do
    expect(@vm.retirement_due?).to be_false
    @vm.retires_on = Date.today

    expect(@vm.retirement_due?).to be_true
  end

  it "#retires_on - tomorrow" do
    expect(@vm.retirement_due?).to be_false
    @vm.retires_on = Date.today + 1

    expect(@vm.retirement_due?).to be_false
  end

  it "#retirement_warn" do
    expect(@vm.retirement_warn).to be_nil
    @vm.update_attributes(:retirement_last_warn => Date.today)
    @vm.retirement_warn = 60

    expect(@vm.retirement_warn).to eq(60)
    expect(@vm.retirement_last_warn).to be_nil
  end

  it "#retirement_due?" do
    vm = FactoryGirl.create(:vm_vmware, :ems_id => @ems.id)
    expect(vm.retirement_due?).to be_false
    vm.update_attributes(:retires_on => Date.today + 1.day)
    expect(vm.retirement_due?).to be_false

    vm.retires_on = Date.today

    vm.update_attributes(:retires_on => Date.today)
    expect(vm.retirement_due?).to be_true

    vm.update_attributes(:retires_on => Date.today - 1.day)
    expect(vm.retirement_due?).to be_true
  end

  it "#raise_retirement_event" do
    event_name = 'foo'
    event_hash = {:vm => @vm, :host => @vm.host, :type => "VmVmware"}

    expect(MiqAeEvent).to receive(:raise_evm_event).with(event_name, @vm, event_hash).once

    @vm.raise_retirement_event(event_name)
  end

  it "#raise_audit_event" do
    event_name = 'foo'
    message = 'bar'
    vm = FactoryGirl.create(:vm_vmware)
    event_hash = { :target_class => "Vm", :target_id => vm.id.to_s, :event => event_name, :message => message }
    expect(AuditEvent).to receive(:success).with(event_hash)

    vm.raise_audit_event(event_name, message)
  end

end
