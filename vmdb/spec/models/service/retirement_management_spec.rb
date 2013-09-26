require "spec_helper"

describe "Service Retirement Management" do

  before(:each) do
    @guid = MiqUUID.new_guid
    MiqServer.stub(:my_guid).and_return(@guid)

    @zone       = FactoryGirl.create(:zone)
    @miq_server = FactoryGirl.create(:miq_server, :guid => @guid, :zone => @zone)
    MiqServer.stub(:my_server).and_return(@miq_server)
    @service = FactoryGirl.create(:service)
  end

  it "#retirement_check" do
    MiqAeEvent.should_receive(:raise_evm_event)
    @service.update_attributes(:retires_on => 90.days.ago, :retirement_warn => 60, :retirement_last_warn => nil)
    expect(@service.retirement_last_warn).to be_nil
    @service.class.any_instance.should_receive(:retire_now).once
    @service.retirement_check
    @service.reload
    expect(@service.retirement_last_warn).not_to be_nil
    expect(Time.now.utc - @service.retirement_last_warn).to be < 30
  end

  it "#start_retirement" do
    expect(@service.retirement_state).to be_nil
    @service.start_retirement
    @service.reload
    expect(@service.retirement_state).to eq("retiring")
  end

  it "#retire_now" do
    expect(@service.retirement_state).to be_nil
    expect(MiqAeEvent).to receive(:raise_evm_event).once
    @service.retire_now
    @service.reload
  end

  it "#retire_service_resources" do
    ems = FactoryGirl.create(:ems_vmware, :zone => @zone)
    vm  = FactoryGirl.create(:vm_vmware, :ems_id => ems.id)
    @service << vm
    expect(@service.service_resources).to have(1).thing
    expect(@service.service_resources.first.resource).to receive(:retire_now).once
    @service.retire_service_resources
  end

  it "#finish_retirement" do
    expect(@service.retirement_state).to be_nil
    @service.finish_retirement
    @service.reload
    expect(@service.retired).to be_true
    expect(@service.retires_on).to eq(Date.today)
    expect(@service.retirement_state).to eq("retired")
  end

  it "#is_or_being_retired - false" do
    expect(@service.retirement_state).to be_nil
    expect(@service.is_or_being_retired?).to be_false
  end

  it "#is_or_being_retired - true" do
    @service.update_attributes(:retirement_state => 'retiring')
    expect(@service.is_or_being_retired?).to be_true
  end

  it "#retires_on - today" do
    expect(@service.retirement_due?).to be_false
    @service.retires_on = Date.today
    expect(@service.retirement_due?).to be_true
  end

  it "#retires_on - tomorrow" do
    expect(@service.retirement_due?).to be_false
    @service.retires_on = Date.today + 1
    expect(@service.retirement_due?).to be_false
  end

  it "#retirement_warn" do
    expect(@service.retirement_warn).to be_nil
    @service.update_attributes(:retirement_last_warn => Date.today)
    @service.retirement_warn = 60
    expect(@service.retirement_warn).to eq(60)
    expect(@service.retirement_last_warn).to be_nil
  end

  it "#retirement_due?" do
    expect(@service.retirement_due?).to be_false

    @service.update_attributes(:retires_on => Date.today + 1.day)
    expect(@service.retirement_due?).to be_false

    @service.update_attributes(:retires_on => Date.today)
    expect(@service.retirement_due?).to be_true

    @service.update_attributes(:retires_on => Date.today - 1.day)
    expect(@service.retirement_due?).to be_true
  end

  it "#raise_retirement_event" do
    event_name = 'foo'
    event_hash = { :service => @service, :type => "Service" }
    expect(MiqAeEvent).to receive(:raise_evm_event).with(event_name, @service, event_hash)
    @service.raise_retirement_event(event_name)
  end

  it "#raise_audit_event" do
    event_name = 'foo'
    message = 'bar'
    event_hash = { :target_class => "Service", :target_id => @service.id.to_s, :event => event_name, :message => message }
    expect(AuditEvent).to receive(:success).with(event_hash)
    @service.raise_audit_event(event_name, message)
  end
end
