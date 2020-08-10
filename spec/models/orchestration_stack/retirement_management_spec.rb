describe "Service Retirement Management" do
  let(:user) { FactoryBot.create(:user_miq_request_approver) }
  let(:orchestration_stack) { FactoryBot.create(:orchestration_stack) }
  let(:stack_with_owner) { FactoryBot.create(:orchestration_stack, :evm_owner => user) }

  context "with zone/ems" do
    before do
      @miq_server = EvmSpecHelper.local_miq_server
      @zone = @miq_server.zone
      ems = FactoryBot.create(:ext_management_system, :zone => @zone)
      @stack = FactoryBot.create(:orchestration_stack, :ext_management_system => ems)
    end

    describe "#retirement_check" do
      context "with user" do
        it "uses user as requester" do
          expect(MiqEvent).to receive(:raise_evm_event)
          stack_with_owner.update_attributes(:retires_on => 90.days.ago, :retirement_warn => 60, :retirement_last_warn => nil)
          expect(stack_with_owner.retirement_last_warn).to be_nil
          stack_with_owner.retirement_check
          stack_with_owner.reload
          expect(stack_with_owner.retirement_last_warn).not_to be_nil
          expect(stack_with_owner.retirement_requester).to eq(user.userid)
        end
      end

      context "with deleted user" do
        before do
          # system_context_retirement relies on the presence of a user with this userid
          FactoryBot.create(:user, :userid => 'admin', :role => 'super_administrator')
          user.destroy
          stack_with_owner.reload
        end

        it "uses admin as requester" do
          expect(MiqEvent).to receive(:raise_evm_event)
          stack_with_owner.update_attributes(:retires_on => 90.days.ago, :retirement_warn => 60, :retirement_last_warn => nil)
          expect(stack_with_owner.retirement_last_warn).to be_nil
          stack_with_owner.retirement_check
          stack_with_owner.reload
          expect(stack_with_owner.retirement_last_warn).not_to be_nil
          expect(stack_with_owner.retirement_requester).to eq("admin")
        end
      end

      context "preventing creation of duplicate retirement request" do
        before do
          stack_with_owner.update(:retires_on => Time.zone.today)
          @request = FactoryBot.create(:orchestration_stack_retire_request, :requester => user, :options => {:src_ids => [stack_with_owner.id]})
        end

        context "retirement request not approved yet" do
          it "create request if existing request's state is 'finished'" do
            @request.update(:request_state => 'finished')
            expect(stack_with_owner.class).to receive(:make_retire_request)
            stack_with_owner.retirement_check
          end

          it "create request if existing request's status is 'Error'" do
            @request.update(:status => 'Error')
            expect(stack_with_owner.class).to receive(:make_retire_request)
            stack_with_owner.retirement_check
          end

          it "does not create request if existing request not finished and status is not 'Error'" do
            expect(stack_with_owner.class).not_to receive(:make_retire_request)
            stack_with_owner.retirement_check
          end
        end
      end
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
      message = "OrchestrationStack: [#{orchestration_stack.name}], Retires On: [#{Time.zone.now.strftime("%x %R %Z")}], has been retired"
      expect(orchestration_stack).to receive(:raise_audit_event).with("orchestration_stack_retired", message, nil)

      orchestration_stack.finish_retirement

      expect(orchestration_stack.retirement_state).to eq("retired")
    end

    it "#mark_retired" do
      expect(@stack.retirement_state).to be_nil
      @stack.mark_retired
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

    it "#raise_retirement_event without user" do
      event_name = 'foo'
      event_hash = {
        :userid              => nil,
        :orchestration_stack => @stack,
        :type                => "OrchestrationStack",
      }

      expect(MiqEvent).to receive(:raise_evm_event).with(@stack, event_name, event_hash, :zone => @zone.name)
      @stack.raise_retirement_event(event_name)
    end

    it "#raise_retirement_event with user" do
      event_name = 'foo'
      event_hash = {
        :userid              => user.userid,
        :orchestration_stack => @stack,
        :type                => "OrchestrationStack",
      }

      expect(MiqEvent).to receive(:raise_evm_event).with(@stack, event_name, event_hash, :zone => @zone.name, :user_id => user.id, :group_id => user.current_group.id, :tenant_id => user.current_tenant.id)
      @stack.raise_retirement_event(event_name, user.userid)
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
      stack_without_zone = FactoryBot.create(:orchestration_stack, :ext_management_system => nil)
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
