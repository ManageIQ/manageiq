describe "Service Retirement Management" do
  let!(:user) { FactoryGirl.create(:user_miq_request_approver, :userid => "admin") }
  context "with zone/ems" do
    before do
      @miq_server = EvmSpecHelper.local_miq_server
      @zone = @miq_server.zone
      ems = FactoryGirl.create(:ext_management_system, :zone => @zone)
      @stack = FactoryGirl.create(:orchestration_stack, :ext_management_system => ems)
    end

    it "#retirement_check" do
      expect(MiqEvent).to receive(:raise_evm_event)
      @stack.update_attributes(:retires_on => 90.days.ago, :retirement_warn => 60, :retirement_last_warn => nil)
      expect(@stack.retirement_last_warn).to be_nil
      @stack.retirement_check
      @stack.reload
      expect(@stack.retirement_last_warn).not_to be_nil
      expect(@stack.retirement_requester).to eq(user.userid)
    end

    it "#start_retirement" do
      expect(@stack.retirement_state).to be_nil
      @stack.start_retirement
      @stack.reload
      expect(@stack.retirement_state).to eq("retiring")
    end

    it "#retire_now" do
      expect(@stack.retirement_state).to be_nil
      expect(OrchestrationStackRetireRequest).to_not receive(:make_request)
      @stack.retire_now
      @stack.reload
    end

    it "#retire_now with userid" do
      expect(@stack.retirement_state).to be_nil
      expect(OrchestrationStackRetireRequest).to_not receive(:make_request)

      @stack.retire_now('freddy')
      @stack.reload
    end

    it "#retire_now without userid" do
      expect(@stack.retirement_state).to be_nil
      expect(OrchestrationStackRetireRequest).to_not receive(:make_request)

      @stack.retire_now
      @stack.reload
    end

    it "#retire warn" do
      expect(AuditEvent).to receive(:success).once
      options = {}
      options[:warn] = 2.days.to_i
      @stack.retire(options)
      @stack.reload
      expect(@stack.retirement_warn).to eq(options[:warn])
    end

    it "#retire date" do
      expect(AuditEvent).to receive(:success).once
      options = {}
      options[:date] = Time.zone.today
      @stack.retire(options)
      @stack.reload
      expect(@stack.retires_on).to eq(options[:date])
    end

    it "#finish_retirement" do
      expect(@stack.retirement_state).to be_nil
      @stack.finish_retirement
      @stack.reload
      expect(@stack.retired).to be_truthy
      expect(@stack.retires_on).to be_between(Time.zone.now - 1.hour, Time.zone.now + 1.second)
      expect(@stack.retirement_state).to eq("retired")
    end

    it "#retiring - false" do
      expect(@stack.retirement_state).to be_nil
      expect(@stack.retiring?).to be_falsey
    end

    it "#retiring - true" do
      @stack.update_attributes(:retirement_state => 'retiring')
      expect(@stack.retiring?).to be_truthy
    end

    it "#error_retiring - false" do
      expect(@stack.retirement_state).to be_nil
      expect(@stack.error_retiring?).to be_falsey
    end

    it "#error_retiring - true" do
      @stack.update_attributes(:retirement_state => 'error')
      expect(@stack.error_retiring?).to be_truthy
    end

    it "#retires_on - today" do
      expect(@stack.retirement_due?).to be_falsey
      @stack.retires_on = Time.zone.today
      expect(@stack.retirement_due?).to be_truthy
    end

    it "#retires_on - tomorrow" do
      expect(@stack.retirement_due?).to be_falsey
      @stack.retires_on = Time.zone.today + 1
      expect(@stack.retirement_due?).to be_falsey
    end

    it "#retirement_due?" do
      expect(@stack.retirement_due?).to be_falsey

      @stack.update_attributes(:retires_on => Time.zone.today + 1.day)
      expect(@stack.retirement_due?).to be_falsey

      @stack.update_attributes(:retires_on => Time.zone.today)
      expect(@stack.retirement_due?).to be_truthy

      @stack.update_attributes(:retires_on => Time.zone.today - 1.day)
      expect(@stack.retirement_due?).to be_truthy
    end

    it "#raise_retirement_event" do
      event_name = 'foo'
      event_hash = {
        :userid              => nil,
        :orchestration_stack => @stack,
        :type                => "OrchestrationStack",
      }

      expect(MiqEvent).to receive(:raise_evm_event).with(@stack, event_name, event_hash, :zone => @zone.name)
      @stack.raise_retirement_event(event_name)
    end

    it "#raise_audit_event" do
      event_name = 'foo'
      message = 'bar'
      event_hash = {
        :target_class => "OrchestrationStack",
        :target_id    => @stack.id.to_s,
        :event        => event_name,
        :message      => message
      }
      expect(AuditEvent).to receive(:success).with(event_hash)
      @stack.raise_audit_event(event_name, message)
    end
  end

  context "without zone/ems" do
    it "#raise_retirement_event" do
      stack_without_zone = FactoryGirl.create(:orchestration_stack, :ext_management_system => nil)
      event_name = 'foo'
      event_hash = {
        :userid              => nil,
        :orchestration_stack => stack_without_zone,
        :type                => "OrchestrationStack",
      }

      expect(MiqEvent).to receive(:raise_evm_event).with(stack_without_zone, event_name, event_hash, {})
      stack_without_zone.raise_retirement_event(event_name)
    end
  end
end
