describe "VM Retirement Management" do
  let!(:user) { FactoryGirl.create(:user_miq_request_approver) }
  let(:region) { FactoryGirl.create(:miq_region, :region => ApplicationRecord.my_region_number) }
  let(:vm2) { FactoryGirl.create(:vm) }

  before do
    @zone = EvmSpecHelper.local_miq_server.zone
    @ems = FactoryGirl.create(:ems_vmware, :zone => @zone)
    @vm = FactoryGirl.create(:vm_vmware, :ems_id => @ems.id, :evm_owner => user)
  end

  it "#retirement_check" do
    expect(MiqEvent).to receive(:raise_evm_event).once
    @vm.update_attributes(:retires_on => 90.days.ago, :retirement_warn => 60, :retirement_last_warn => nil)
    expect(@vm.retirement_last_warn).to be_nil
    @vm.retirement_check
    @vm.reload
    expect(@vm.retirement_last_warn).not_to be_nil
    expect(@vm.retirement_requester).to eq(user.userid)
  end

  it "#start_retirement" do
    expect(@vm.retirement_state).to be_nil
    @vm.start_retirement
    @vm.reload

    expect(@vm.retirement_state).to eq("retiring")
  end

  it "#retire_now" do
    expect(MiqEvent).to receive(:raise_evm_event).once
    @vm.retire_now
    expect(@vm.retirement_state).to eq('initializing')
  end

  it "#retire_now when called more than once" do
    expect(MiqEvent).to receive(:raise_evm_event).once
    3.times { @vm.retire_now(user) }
    expect(@vm.retirement_state).to eq('initializing')
  end

  it "#retire_now not called when already retiring" do
    @vm.update_attributes(:retirement_state => 'retiring')
    expect(MiqEvent).to receive(:raise_evm_event).exactly(0).times
    @vm.retire_now
  end

  it "#retire_now not called when already retired" do
    @vm.update_attributes(:retirement_state => 'retired')
    expect(MiqEvent).to receive(:raise_evm_event).exactly(0).times
    @vm.retire_now
  end

  it "#retire_now with userid" do
    event_name = 'request_vm_retire'
    event_hash = {:userid => user.userid, :vm => @vm, :host => @vm.host, :type => "ManageIQ::Providers::Vmware::InfraManager::Vm"}
    options = {:zone => @zone.name, :user_id => user.id, :group_id => MiqGroup.last.id, :tenant_id => Tenant.last.id}

    expect(MiqEvent).to receive(:raise_evm_event).with(@vm, event_name, event_hash, options).once

    @vm.retire_now(user.userid)
  end

  it "#retire_now without userid" do
    event_name = 'request_vm_retire'
    event_hash = {:userid => nil, :vm => @vm, :host => @vm.host, :type => "ManageIQ::Providers::Vmware::InfraManager::Vm"}
    options = {:zone => @zone.name}

    expect(MiqEvent).to receive(:raise_evm_event).with(@vm, event_name, event_hash, :zone => @zone.name).once

    @vm.retire_now
  end

  it "#retire warn" do
    expect(AuditEvent).to receive(:success).once
    options = {}
    options[:warn] = 2.days.to_i
    @vm.retire(options)
    @vm.reload
    expect(@vm.retirement_warn).to eq(options[:warn])
  end

  describe "retire request" do
    it "with one src_id" do
      expect(VmRetireRequest).to receive(:make_request).with(nil, {:src_ids => [@vm.id], :__request_type__ => "vm_retire"}, user, true)
      Vm.make_retire_request(@vm.id, user)
    end

    it "with many src_ids" do
      expect(VmRetireRequest).to receive(:make_request).with(nil, {:src_ids => [@vm.id, vm2.id], :__request_type__ => "vm_retire"}, user, true)
      Vm.make_retire_request(@vm.id, vm2.id, user)
    end
  end

  it "#retire date" do
    expect(AuditEvent).to receive(:success).once
    options = {}
    options[:date] = Time.zone.today
    @vm.retire(options)
    @vm.reload
    expect(@vm.retires_on).to eq(options[:date])
  end

  it "#finish_retirement" do
    expect(@vm.retirement_state).to be_nil
    @vm.finish_retirement
    @vm.reload

    expect(@vm.retired).to eq(true)
    expect(@vm.retires_on).to be_between(Time.zone.now - 1.hour, Time.zone.now + 1.second)
    expect(@vm.retirement_state).to eq("retired")
  end

  it "#retiring - false" do
    expect(@vm.retirement_state).to be_nil
    expect(@vm.retiring?).to be_falsey
  end

  it "#retiring - true" do
    @vm.update_attributes(:retirement_state => 'retiring')

    expect(@vm.retiring?).to be_truthy
  end

  it "#error_retiring - false" do
    expect(@vm.retirement_state).to be_nil
    expect(@vm.error_retiring?).to be_falsey
  end

  it "#error_retiring - true" do
    @vm.update_attributes(:retirement_state => 'error')

    expect(@vm.error_retiring?).to be_truthy
  end

  it "#retires_on - today" do
    expect(@vm.retirement_due?).to be_falsey
    @vm.retires_on = Time.zone.today

    expect(@vm.retirement_due?).to be_truthy
  end

  it "#retires_on - tomorrow" do
    expect(@vm.retirement_due?).to be_falsey
    @vm.retires_on = Time.zone.today + 1

    expect(@vm.retirement_due?).to be_falsey
  end

  it "#retirement_due?" do
    vm = FactoryGirl.create(:vm_vmware, :ems_id => @ems.id)
    expect(vm.retirement_due?).to be_falsey
    vm.update_attributes(:retires_on => Time.zone.today + 1.day)
    expect(vm.retirement_due?).to be_falsey

    vm.retires_on = Time.zone.today

    vm.update_attributes(:retires_on => Time.zone.today)
    expect(vm.retirement_due?).to be_truthy

    vm.update_attributes(:retires_on => Time.zone.today - 1.day)
    expect(vm.retirement_due?).to be_truthy
  end

  it "#raise_retirement_event without user" do
    event_name = 'foo'
    event_hash = {:userid => nil, :vm => @vm, :host => @vm.host, :type => "ManageIQ::Providers::Vmware::InfraManager::Vm"}

    expect(MiqEvent).to receive(:raise_evm_event).with(@vm, event_name, event_hash, :zone => @zone.name).once

    @vm.raise_retirement_event(event_name)
  end

  it "#raise_retirement_event with user" do
    event_name = 'foo'
    event_hash = {:userid => user, :vm => @vm, :host => @vm.host, :type => "ManageIQ::Providers::Vmware::InfraManager::Vm"}
    options = {:zone => @zone.name, :user_id => user.id, :group_id => user.current_group_id, :tenant_id => user.current_tenant.id }

    expect(MiqEvent).to receive(:raise_evm_event).with(@vm, event_name, event_hash, options).once
    @vm.raise_retirement_event(event_name, user)
  end

  it "#raise_audit_event" do
    event_name = 'foo'
    message = 'bar'
    vm = FactoryGirl.create(:vm_vmware)
    event_hash = {:target_class => "Vm", :target_id => vm.id.to_s, :event => event_name, :message => message}
    expect(AuditEvent).to receive(:success).with(event_hash)

    vm.raise_audit_event(event_name, message)
  end

  it "reset retirement state in future" do
    @vm.update_attributes(:retirement_state => 'retiring')
    @vm.retire(:date => Time.zone.today + 1.day)

    expect(@vm.reload.retirement_state).to be_nil
  end

  it "reset retirement state in past" do
    @vm.update_attributes(:retirement_state => 'retiring')
    @vm.retire(:date => Time.zone.today - 1.day)

    expect(@vm.reload.retirement_state).to eq('retiring')
  end
end
