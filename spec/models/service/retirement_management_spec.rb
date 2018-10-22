describe "Service Retirement Management" do
  let!(:user) { FactoryGirl.create(:user_miq_request_approver, :userid => 'admin') }
  let(:service_without_owner) { FactoryGirl.create(:service) }
  let(:service3) { FactoryGirl.create(:service) }
  before do
    @server = EvmSpecHelper.local_miq_server
    @service = FactoryGirl.create(:service, :evm_owner_id => user.id)
  end

  # shouldn't be running make_retire_request because it's the bimodal not from ui part
  context "with user" do
    it "#retirement_check" do
      User.with_user(user) do
        expect(MiqEvent).to receive(:raise_evm_event)
        @service.update_attributes(:retires_on => 90.days.ago, :retirement_warn => 60, :retirement_last_warn => nil)
        expect(@service.retirement_last_warn).to be_nil
        @service.retirement_check
        @service.reload
        expect(@service.retirement_last_warn).not_to be_nil
        expect(@service.retirement_requester).to eq(user.userid)
      end
    end
  end

  context "without user" do
    it "#retirement_check" do
      expect(MiqEvent).to receive(:raise_evm_event)
      service_without_owner.update_attributes(:retires_on => 90.days.ago, :retirement_warn => 60, :retirement_last_warn => nil)
      expect(service_without_owner.retirement_last_warn).to be_nil
      service_without_owner.retirement_check
      service_without_owner.reload
      expect(service_without_owner.retirement_last_warn).not_to be_nil
      expect(service_without_owner.retirement_requester).to eq(user.userid)
      expect(MiqRequest.first.userid).to eq("admin")
    end
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
    expect(@service.retirement_state).to eq('initializing')
  end

  it "#retire_now when called more than once" do
    expect(@service.retirement_state).to be_nil
    expect(MiqEvent).to receive(:raise_evm_event).once
    3.times { @service.retire_now }
    expect(@service.retirement_state).to eq('initializing')
  end

  it "#retire_now not called when already retiring" do
    @service.update_attributes(:retirement_state => 'retiring')
    expect(MiqEvent).to receive(:raise_evm_event).exactly(0).times
    @service.retire_now
  end

  it "#retire_now not called when already retired" do
    @service.update_attributes(:retirement_state => 'retired')
    expect(MiqEvent).to receive(:raise_evm_event).exactly(0).times
    @service.retire_now
  end

  it "#retire_now with userid" do
    expect(@service.retirement_state).to be_nil
    event_name = 'request_service_retire'
    event_hash = {:userid => user.userid, :service => @service, :type => "Service"}
    options = {:user_id => user.id, :group_id => MiqGroup.last.id, :tenant_id => Tenant.first.id}

    expect(MiqEvent).to receive(:raise_evm_event).with(@service, event_name, event_hash, options).once

    @service.retire_now(user.userid)
  end

  it "#retire_now without userid" do
    expect(@service.retirement_state).to be_nil
    event_name = 'request_service_retire'
    event_hash = {:userid => nil, :service => @service, :type => "Service"}

    expect(MiqEvent).to receive(:raise_evm_event).with(@service, event_name, event_hash, {}).once

    @service.retire_now
  end

  it "#retire warn" do
    expect(AuditEvent).to receive(:success).once
    options = {}
    options[:warn] = 2.days.to_i
    @service.retire(options)
    @service.reload
    expect(@service.retirement_warn).to eq(options[:warn])
  end

  it "with one src_id" do
    expect(ServiceRetireRequest).to receive(:make_request).with(nil, {:src_ids => [service3.id], :__request_type__ => "service_retire"}, user, true)
    @service.class.to_s.demodulize.constantize.make_retire_request(service3.id, user)
  end

  it "with many src_ids" do
    expect(ServiceRetireRequest).to receive(:make_request).with(nil, {:src_ids => [@service.id, service3.id, service_without_owner.id], :__request_type__ => "service_retire"}, user, true)
    @service.class.to_s.demodulize.constantize.make_retire_request(@service.id, service3.id, service_without_owner.id, user)
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
    expect(@service.service_resources.first.resource).to_not receive(:retire_now)
    @service.retire_service_resources
  end

  it "#retire_service_resources should get service's retirement_requester" do
    ems = FactoryGirl.create(:ems_vmware, :zone => @server.zone)
    vm  = FactoryGirl.create(:vm_vmware, :ems_id => ems.id)
    userid = 'freddy'
    @service.update_attributes(:retirement_requester => userid)
    @service << vm
    expect(@service.service_resources.size).to eq(1)
    expect(@service.service_resources.first.resource).to_not receive(:retire_now).with(userid)
    @service.retire_service_resources
  end

  it "#retire_service_resources should get service's nil retirement_requester" do
    ems = FactoryGirl.create(:ems_vmware, :zone => @server.zone)
    vm  = FactoryGirl.create(:vm_vmware, :ems_id => ems.id)
    @service << vm
    expect(@service.service_resources.size).to eq(1)
    expect(@service.service_resources.first.resource).to_not receive(:retire_now).with(nil)
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
    event_hash = {:userid => nil, :service => @service, :type => "Service"}
    expect(MiqEvent).to receive(:raise_evm_event).with(@service, event_name, event_hash, {})
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
