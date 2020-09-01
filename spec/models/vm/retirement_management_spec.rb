RSpec.describe "VM Retirement Management" do
  let(:user) { FactoryBot.create(:user_miq_request_approver) }
  let(:vm_with_owner) { FactoryBot.create(:vm, :evm_owner => user, :host => FactoryBot.create(:host)) }
  let(:region) { FactoryBot.create(:miq_region, :region => ApplicationRecord.my_region_number) }
  let(:vm2) { FactoryBot.create(:vm) }

  before do
    @zone = EvmSpecHelper.local_miq_server.zone
    @ems = FactoryBot.create(:ems_vmware, :zone => @zone)
    @vm = FactoryBot.create(:vm_vmware, :ems_id => @ems.id)
  end

  describe "#retirement_check" do
    before do
      FactoryBot.create(:miq_event_definition, :name => :request_vm_retire)
      # admin user is needed to process Events
      # system_context_retirement relies on the presence of a user with this userid
      FactoryBot.create(:user_with_group, :userid => "admin")
    end

    context "with user" do
      it "uses user as requester" do
        vm_with_owner.update(:retires_on => 90.days.ago, :retirement_warn => 60, :retirement_last_warn => nil)
        expect(vm_with_owner.retirement_last_warn).to be_nil

        allow(MiqAeEngine).to receive_messages(:deliver => ['ok', 'success', MiqAeEngine::MiqAeWorkspaceRuntime.new])
        vm_with_owner.retirement_check
        status, message, result = MiqQueue.first.deliver
        MiqQueue.first.delivered(status, message, result)

        vm_with_owner.reload
        expect(vm_with_owner.retirement_last_warn).not_to be_nil
        expect(vm_with_owner.retirement_requester).to eq(user.userid)
      end
    end

    context "with user lacking group" do
      let(:user1) { FactoryBot.create(:user) }
      let(:vm_with_owner_no_group) { FactoryBot.create(:vm, :evm_owner => user1, :host => FactoryBot.create(:host)) }

      it "uses user as requester" do
        vm_with_owner_no_group.update(:retires_on => 90.days.ago, :retirement_warn => 60, :retirement_last_warn => nil)

        expect(vm_with_owner.retirement_last_warn).to be_nil
        allow(MiqAeEngine).to receive_messages(:deliver => ['ok', 'success', MiqAeEngine::MiqAeWorkspaceRuntime.new])
        vm_with_owner_no_group.retirement_check
        status, message, result = MiqQueue.first.deliver
        MiqQueue.first.delivered(status, message, result)

        expect(vm_with_owner_no_group.retirement_last_warn).not_to be_nil
        # the next test is only nil because we're not creating a true super admin in these specs
        expect(vm_with_owner_no_group.retirement_requester).to eq(nil)
      end
    end

    context "without user" do
      before do
        user.destroy
        vm_with_owner.reload
      end

      it "uses admin as requester" do
        vm_with_owner.update(:retires_on => 90.days.ago, :retirement_warn => 60, :retirement_last_warn => nil)
        expect(vm_with_owner.retirement_last_warn).to be_nil

        allow(MiqAeEngine).to receive_messages(:deliver => ['ok', 'success', MiqAeEngine::MiqAeWorkspaceRuntime.new])
        vm_with_owner.retirement_check
        status, message, result = MiqQueue.first.deliver
        MiqQueue.first.delivered(status, message, result)

        vm_with_owner.reload
        expect(vm_with_owner.retirement_last_warn).not_to be_nil
        expect(vm_with_owner.retirement_requester).to eq('admin')
      end
    end

    context "preventing creation of duplicate retirement request" do
      before do
        vm_with_owner.update(:retires_on => Time.zone.today)
        @request = FactoryBot.create(:vm_retire_request, :requester => user, :source_id => vm_with_owner.id)
      end

      it "create request if existing request's state is 'finished' regardless approval status" do
        @request.update(:request_state => 'finished')
        expect(vm_with_owner.class).to receive(:make_retire_request)
        vm_with_owner.retirement_check

        @request.update(:approval_state => "approved")
        expect(vm_with_owner.class).to receive(:make_retire_request)
        vm_with_owner.retirement_check
      end

      it "create request if existing request's status is 'Error' regardless approval status" do
        @request.update(:status => 'Error')
        expect(vm_with_owner.class).to receive(:make_retire_request)
        vm_with_owner.retirement_check

        @request.update(:approval_state => "approved")
        expect(vm_with_owner.class).to receive(:make_retire_request)
        vm_with_owner.retirement_check
      end

      it "does not create request if existing request not approved and not finished and status is not 'Error'" do
        expect(vm_with_owner.class).not_to receive(:make_retire_request)
        vm_with_owner.retirement_check
      end
    end
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
    @vm.update(:retirement_state => 'retiring')
    expect(MiqEvent).to receive(:raise_evm_event).exactly(0).times
    @vm.retire_now
  end

  it "#retire_now not called when already retired" do
    @vm.update(:retirement_state => 'retired')
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
    let(:ws) { MiqAeEngine::MiqAeWorkspaceRuntime.new }
    before do
      FactoryBot.create(:miq_event_definition, :name => :request_vm_retire)
      # admin user is needed to process Events
      FactoryBot.create(:user_with_group, :userid => "admin")
    end

    it "with one src_id" do
      allow(Vm).to receive(:where).with(:id => [@vm.id]).and_return([@vm])
      expect(@vm).to receive(:check_policy_prevent).once
      Vm.make_retire_request(@vm.id, user)
    end

    it "with many src_ids" do
      allow(Vm).to receive(:where).with(:id => [@vm.id, vm2.id]).and_return([@vm, vm2])
      expect(@vm).to receive(:check_policy_prevent).once
      expect(vm2).to receive(:check_policy_prevent).once
      Vm.make_retire_request(@vm.id, vm2.id, user)
    end

    it "initiated by system" do
      expect(VmRetireRequest).to receive(:make_request).with(nil, {:src_ids => [@vm.id], :__initiated_by__ => 'system', :__request_type__ => "vm_retire"}, user)

      allow(MiqAeEngine).to receive_messages(:deliver => ['ok', 'success', ws])
      Vm.make_retire_request(@vm.id, user, :initiated_by => 'system')
      status, message, result = MiqQueue.first.deliver
      MiqQueue.first.delivered(status, message, result)
    end

    it "with user as initiated_by" do
      log_stub = instance_double("_log")
      expect(Vm).to receive(:_log).and_return(log_stub).at_least(:once)
      expect(log_stub).to receive(:info).at_least(:once)
      expect(log_stub).not_to receive(:error).with("Retirement of [Vm] IDs: [] skipped - target(s) does not exist")
      Vm.make_retire_request(@vm.id, user, :initiated_by => user)

      q = MiqQueue.first
      allow(MiqAeEngine).to receive_messages(:deliver => ['ok', 'success', ws])
      expect(q).to receive(:_log).and_return(log_stub).at_least(:once)
      expect(log_stub).to receive(:error).with(/Validation failed: VmRetireRequest: Initiated by is not included in the list/)
      expect(log_stub).to receive(:log_backtrace)
      status, message, result = q.deliver

      q.delivered(status, message, result)
    end

    it "with user as initiated_by, with unknown vm.id" do
      log_stub = instance_double("_log")
      expect(Vm).to receive(:_log).and_return(log_stub).at_least(:once)
      expect(log_stub).to receive(:info).at_least(:once)
      expect(log_stub).to receive(:error).with("Retirement of [Vm] IDs: [123] skipped - target(s) does not exist")
      Vm.make_retire_request(@vm.id, 123, user, :initiated_by => user)

      q = MiqQueue.first

      allow(MiqAeEngine).to receive_messages(:deliver => ['ok', 'success', ws])
      expect(q).to receive(:_log).and_return(log_stub).at_least(:once)
      expect(log_stub).to receive(:error).with(/Validation failed: VmRetireRequest: Initiated by is not included in the list/)
      expect(log_stub).to receive(:log_backtrace)
      status, message, result = q.deliver
      q.delivered(status, message, result)
    end

    it "policy prevents" do
      expect(VmRetireRequest).not_to receive(:make_request)

      event = {:attributes => {"full_data" => {:policy => {:prevented => true}}}}
      allow(ws).to receive(:get_obj_from_path).with("/").and_return(:event_stream => event)
      allow(MiqAeEngine).to receive_messages(:deliver => ['ok', 'success', ws])
      Vm.make_retire_request(@vm.id, user)
      status, message, _result = MiqQueue.first.deliver
      MiqQueue.first.delivered(status, message, ws)
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
    message = "Vm: [id:<#{vm2.id}>, name:<#{vm2.name}>] with Retires On value: [#{Time.zone.now.strftime("%x %R %Z")}], has been retired"
    expect(vm2).to receive(:raise_audit_event).with("vm_retired", message, nil)

    vm2.finish_retirement

    expect(vm2.retirement_state).to eq("retired")
  end

  it "#mark_retired" do
    expect(@vm.retirement_state).to be_nil
    @vm.mark_retired
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
    @vm.update(:retirement_state => 'retiring')

    expect(@vm.retiring?).to be_truthy
  end

  it "#error_retiring - false" do
    expect(@vm.retirement_state).to be_nil
    expect(@vm.error_retiring?).to be_falsey
  end

  it "#error_retiring - true" do
    @vm.update(:retirement_state => 'error')

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
    vm = FactoryBot.create(:vm_vmware, :ems_id => @ems.id)
    expect(vm.retirement_due?).to be_falsey
    vm.update(:retires_on => Time.zone.today + 1.day)
    expect(vm.retirement_due?).to be_falsey

    vm.retires_on = Time.zone.today

    vm.update(:retires_on => Time.zone.today)
    expect(vm.retirement_due?).to be_truthy

    vm.update(:retires_on => Time.zone.today - 1.day)
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
    vm = FactoryBot.create(:vm_vmware)
    event_hash = {:target_class => "Vm", :target_id => vm.id.to_s, :event => event_name, :message => message}
    expect(AuditEvent).to receive(:success).with(event_hash)

    vm.raise_audit_event(event_name, message)
  end

  it "reset retirement state in future" do
    @vm.update(:retirement_state => 'retiring')
    @vm.retire(:date => Time.zone.today + 1.day)

    expect(@vm.reload.retirement_state).to be_nil
  end

  it "reset retirement state in past" do
    @vm.update(:retirement_state => 'retiring')
    @vm.retire(:date => Time.zone.today - 1.day)

    expect(@vm.reload.retirement_state).to eq('retiring')
  end
end
