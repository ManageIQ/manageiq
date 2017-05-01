describe "Service Retirement Management" do
  before(:each) do
    @server = EvmSpecHelper.local_miq_server
    @service = FactoryGirl.create(:service)
  end

  it "#retirement_check" do
    expect(MiqEvent).to receive(:raise_evm_event)
    @service.update_attributes(:retires_on => 90.days.ago, :retirement_warn => 60, :retirement_last_warn => nil)
    expect(@service.retirement_last_warn).to be_nil
    expect_any_instance_of(@service.class).to receive(:retire_now).once
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
    expect(MiqEvent).to receive(:raise_evm_event).once
    @service.retire_now
    @service.reload
  end

  it "#retire_now with userid" do
    expect(@service.retirement_state).to be_nil
    event_name = 'request_service_retire'
    event_hash = {:service => @service, :type => "Service",
                  :retirement_initiator => "user", :userid => "freddy"}

    expect(MiqEvent).to receive(:raise_evm_event).with(@service, event_name, event_hash).once

    @service.retire_now('freddy')
    @service.reload
  end

  it "#retire_now without userid" do
    expect(@service.retirement_state).to be_nil
    event_name = 'request_service_retire'
    event_hash = {:service => @service, :type => "Service",
                  :retirement_initiator => "system"}

    expect(MiqEvent).to receive(:raise_evm_event).with(@service, event_name, event_hash).once

    @service.retire_now
    @service.reload
  end

  it "#retire warn" do
    expect(AuditEvent).to receive(:success).once
    options = {}
    options[:warn] = 2.days.to_i
    @service.retire(options)
    @service.reload
    expect(@service.retirement_warn).to eq(options[:warn])
  end

  it "#retire date" do
    expect(AuditEvent).to receive(:success).once
    options = {}
    options[:date] = Time.zone.today
    @service.retire(options)
    @service.reload
    expect(@service.retires_on).to eq(options[:date])
  end

  it "#retire_service_resources" do
    ems = FactoryGirl.create(:ems_vmware, :zone => @server.zone)
    vm  = FactoryGirl.create(:vm_vmware, :ems_id => ems.id)
    @service << vm
    expect(@service.service_resources.size).to eq(1)
    expect(@service.service_resources.first.resource).to receive(:retire_now).once
    @service.retire_service_resources
  end

  it "#retire_service_resources should get service's retirement_requester" do
    ems = FactoryGirl.create(:ems_vmware, :zone => @server.zone)
    vm  = FactoryGirl.create(:vm_vmware, :ems_id => ems.id)
    userid = 'freddy'
    @service.update_attributes(:retirement_requester => userid)
    @service << vm
    expect(@service.service_resources.size).to eq(1)
    expect(@service.service_resources.first.resource).to receive(:retire_now).with(userid).once
    @service.retire_service_resources
  end

  it "#retire_service_resources should get service's nil retirement_requester" do
    ems = FactoryGirl.create(:ems_vmware, :zone => @server.zone)
    vm  = FactoryGirl.create(:vm_vmware, :ems_id => ems.id)
    @service << vm
    expect(@service.service_resources.size).to eq(1)
    expect(@service.service_resources.first.resource).to receive(:retire_now).with(nil).once
    @service.retire_service_resources
  end

  it "#finish_retirement" do
    expect(@service.retirement_state).to be_nil
    @service.finish_retirement
    @service.reload
    expect(@service.retired).to be_truthy
    expect(@service.retires_on).to be_between(Time.zone.now - 1.hour, Time.zone.now + 1.second)
    expect(@service.retirement_state).to eq("retired")
  end

  it "#retiring - false" do
    expect(@service.retirement_state).to be_nil
    expect(@service.retiring?).to be_falsey
  end

  it "#retiring - true" do
    @service.update_attributes(:retirement_state => 'retiring')
    expect(@service.retiring?).to be_truthy
  end

  it "#error_retiring - false" do
    expect(@service.retirement_state).to be_nil
    expect(@service.error_retiring?).to be_falsey
  end

  it "#error_retiring - true" do
    @service.update_attributes(:retirement_state => 'error')
    expect(@service.error_retiring?).to be_truthy
  end

  it "#retires_on - today" do
    expect(@service.retirement_due?).to be_falsey
    @service.retires_on = Time.zone.today
    expect(@service.retirement_due?).to be_truthy
  end

  it "#retires_on - tomorrow" do
    expect(@service.retirement_due?).to be_falsey
    @service.retires_on = Time.zone.today + 1
    expect(@service.retirement_due?).to be_falsey
  end

  # it "#retirement_warn" do
  #  expect(@service.retirement_warn).to be_nil
  #   @service.update_attributes(:retirement_last_warn => Time.zone.today)
  #   @service.retirement_warn = 60
  #  expect(@service.retirement_warn).to eq(60)
  #  expect(@service.retirement_last_warn).to be_nil
  # end

  it "#retirement_due?" do
    expect(@service.retirement_due?).to be_falsey

    @service.update_attributes(:retires_on => Time.zone.today + 1.day)
    expect(@service.retirement_due?).to be_falsey

    @service.update_attributes(:retires_on => Time.zone.today)
    expect(@service.retirement_due?).to be_truthy

    @service.update_attributes(:retires_on => Time.zone.today - 1.day)
    expect(@service.retirement_due?).to be_truthy
  end

  it "#raise_retirement_event" do
    event_name = 'foo'
    event_hash = {:service => @service, :type => "Service", :retirement_initiator => "system"}
    expect(MiqEvent).to receive(:raise_evm_event).with(@service, event_name, event_hash)
    @service.raise_retirement_event(event_name)
  end

  it "#raise_audit_event" do
    event_name = 'foo'
    message = 'bar'
    event_hash = {:target_class => "Service", :target_id => @service.id.to_s, :event => event_name, :message => message}
    expect(AuditEvent).to receive(:success).with(event_hash)
    @service.raise_audit_event(event_name, message)
  end
end
