describe MiqPolicy do
  context "Testing edge cases on conditions" do
    # The conditions reflection on MiqPolicy is affected when called through a
    # belongs_to or has_one, which is used under the covers in MiqSet.  This
    # test verifies that changing things under the covers doesn't affect
    # calling conditions.

    before(:each) do
      @ps = FactoryGirl.create(:miq_policy_set)
      @p  = FactoryGirl.create(:miq_policy)
      @ps.add_member(@p)

      @ps2 = FactoryGirl.create(:miq_policy_set)
      @p2  = FactoryGirl.create(:miq_policy)
    end

    it "should return the correct conditions" do
      expect(@ps.miq_policies.first.conditions).to eq([])
      expect(@p.conditions).to eq([])
    end
  end

  context "#description=" do
    subject { FactoryGirl.create(:miq_policy, :description => @description) }

    it "should keep the description < 255" do
      @description = "a" * 30
      expect(subject.description.length).to eq(30)
    end

    it "should raise an error with empty description" do
      @description = nil
      expect { subject.description }.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: Description can't be blank")
    end

    it "should raise an error when description is reset to empty" do
      @description = "a" * 30
      subject.description = nil
      expect { subject.save! }.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: Description can't be blank")
    end
  end

  describe "#seed" do
    let(:miq_policy_instance) { FactoryGirl.create(:miq_policy) }

    context "when fields(towhat, active, mode) are not yet set in database" do
      it "should be filled up by default values" do
        miq_policy_instance.towhat = nil
        miq_policy_instance.active = nil
        miq_policy_instance.mode = nil
        miq_policy_instance.save

        MiqPolicy.seed

        updated_miq_policy = MiqPolicy.find(miq_policy_instance.id)

        expect(updated_miq_policy.towhat).to eq("Vm")
        expect(updated_miq_policy.active).to eq(true)
        expect(updated_miq_policy.mode).to eq("control")
      end
    end

    context "when fields(towhat, active, mode) are already set in database" do
      it "should not be filled up by default values" do
        miq_policy_instance.towhat = "Host"
        miq_policy_instance.active = false
        miq_policy_instance.mode = "compliance"
        miq_policy_instance.save

        MiqPolicy.seed

        miq_policy = MiqPolicy.find(miq_policy_instance.id)

        expect(miq_policy.towhat).not_to eq("Vm")
        expect(miq_policy.active).not_to eq(true)
        expect(miq_policy.mode).not_to eq("control")

        # testing that our values stayed untouched
        expect(miq_policy.towhat).to eq("Host")
        expect(miq_policy.active).to eq(false)
        expect(miq_policy.mode).to eq("compliance")
      end
    end
  end

  context "instance methods" do
    let(:event)  { FactoryGirl.create(:miq_event_definition) }
    let(:action) { FactoryGirl.create(:miq_action) }

    let(:policy) do
      cond = FactoryGirl.create(:condition)
      FactoryGirl.create(:miq_policy, :conditions => [cond]).tap do |p|
        p.replace_actions_for_event(event, [[action, {:qualifier => :success}]])
      end
    end

    describe "#events" do
      it "lists miq_event_definition assigned to the policy" do
        expect(policy.events).to eq([event])
      end
    end

    describe "#sync_events, #add_event, #delete_event" do
      let(:new_events) { [FactoryGirl.create(:miq_event_definition), FactoryGirl.create(:miq_event_definition)] }

      it 'synchronizes with new list of events' do
        policy.sync_events(new_events)
        policy.reload
        expect(policy.events).to eq(new_events)
      end
    end

    describe "#actions #actions_for_event, #replace_actions_for_event" do
      let(:new_action)    { FactoryGirl.create(:miq_action) }
      let(:another_event) { FactoryGirl.create(:miq_event_definition) }

      it "lists all actions for the policy" do
        policy.replace_actions_for_event(another_event, [[new_action, {:qualifier => :success}]])
        expect(policy.actions).to match_array([action, new_action])
      end

      it "lists actions for an event" do
        expect(policy.actions_for_event(event, :success)).to eq([action])
      end

      it "replaces actions for an event" do
        policy.replace_actions_for_event(event, [[new_action, {:qualifier => :success}]])
        expect(policy.actions_for_event(event, :success)).to eq([new_action])
      end
    end

    describe "#action_result_for_event" do
      it "finds the action result to be true or false" do
        expect(policy.action_result_for_event(action, event)).to be true
      end
    end

    describe "#copy, .clean_attrs" do
      it "creates new instance based on the existing one" do
        new_policy = policy.copy(:name => 'newname', :description => 'newdesc')
        expect(new_policy.name).to        eq('newname')
        expect(new_policy.description).to eq('newdesc')

        expect(new_policy.id).not_to   eq(policy.id)
        expect(new_policy.guid).not_to eq(policy.guid)

        expect(new_policy.events).to     eq(policy.events)
        expect(new_policy.actions).to    eq(policy.actions)
        expect(new_policy.conditions).to eq(policy.conditions)
      end
    end

    describe "#applies_to?" do
      let(:target_vm)       { FactoryGirl.create(:vm_amazon) }
      let(:target_template) { FactoryGirl.create(:template_infra) }
      let(:target_host)     { FactoryGirl.create(:host) }

      it "applies to target with matched type" do
        expect(policy.applies_to?(target_vm)).to       be_truthy
        expect(policy.applies_to?(target_template)).to be_truthy
        expect(policy.applies_to?(target_host)).to     be_falsey
      end

      context "policy has expression" do
        before do
          policy.expression = "expression"
        end

        it "applies to target when expression evaluates true" do
          expect(Condition).to receive(:evaluate).and_return(true)
          expect(policy.applies_to?(target_vm)).to be_truthy
        end

        it "does not apply to target when expression evaluates false" do
          expect(Condition).to receive(:evaluate).and_return(false)
          expect(policy.applies_to?(target_vm)).to be_falsey
        end
      end
    end
  end

  context "class methods" do
    let(:events)  { [FactoryGirl.create(:miq_event_definition), FactoryGirl.create(:miq_event_definition)] }
    let(:actions) { [FactoryGirl.create(:miq_action), FactoryGirl.create(:miq_action)] }
    let(:conds)   { [FactoryGirl.create(:condition), FactoryGirl.create(:condition)] }
    let(:target)  { FactoryGirl.create(:vm) }

    let(:policies) do
      [
        FactoryGirl.create(:miq_policy, :conditions => [conds[0]], :active => true, :mode => 'control').tap do |p|
          p.replace_actions_for_event(events[0], [[actions[0], {:qualifier => :success}]])
        end,
        FactoryGirl.create(:miq_policy, :conditions => [conds[1]], :active => false).tap do |p|
          p.replace_actions_for_event(events[1], [[actions[1], {:qualifier => :success}]])
        end
      ]
    end

    let(:profiles) do
      [
        FactoryGirl.create(:miq_policy_set).tap { |pf| pf.add_member(policies[0]) },
        FactoryGirl.create(:miq_policy_set).tap { |pf| pf.add_member(policies[1]) },
      ]
    end

    before { policies }

    describe ".resolve" do
      it "resolves all policies" do
        results = described_class.resolve(FactoryGirl.create(:vm))
        expect(results.size).to eq(2)
      end

      it "resolves policies by event" do
        results = described_class.resolve(FactoryGirl.create(:vm), policies.collect(&:name), events[1])
        expect(results.size).to eq(1)
        result = results[0]
        expect(result).to include(
          'name'        => policies[1].name,
          'description' => policies[1].description,
          'towhat'      => policies[1].towhat,
          'expression'  => policies[1].expression,
          'result'      => 'N/A'
        )
        expect(result['conditions'][0]).to include(
          'name'        => conds[1].name,
          'description' => conds[1].description,
          'result'      => 'deny',
          'expression'  => conds[1].expression.exp.merge('result' => false)
        )
        expect(result['actions'][0]).to include(
          'name'        => actions[1].name,
          'description' => actions[1].description,
          'result'      => 'N/A'
        )
      end
    end

    describe ".get_policies_for_target" do
      it 'gets profiles and policies for a target' do
        allow(target).to receive(:get_policies).and_return(profiles)
        prof_list, pol_list = described_class.get_policies_for_target(target, 'control', events[0].name)
        expect(prof_list.size).to eq(2)
        expect(pol_list.size).to  eq(1)
        expect(pol_list[0]).to    eq(policies[0])
      end
    end

    describe ".enforce_policy" do
      it 'executes policies for a target' do
        allow(target).to receive(:get_policies).and_return(profiles)
        res = described_class.enforce_policy(target, events[0].name)
        expect(res[:result]).to be false
        # to exclude timestamps which cause test failures in some systems due to precision
        expected_detail = policies[0].attributes.except('created_on').except('updated_on')
        expect(res[:details][0]).to include(expected_detail.merge('result' => false))

        # also exclude expression that added a transient state during evaluation
        expected_condition = conds[0].attributes.except('created_on').except('updated_on').except('expression')
        expect(res[:details][0]['conditions'][0]).to include(expected_condition.merge('result' => 'deny'))
      end

      it 'acts on successful policy' do
        succeeded = []
        failed    = [policies[0]]
        allow(target).to receive(:get_policies).and_return(profiles)

        expect(MiqAction).to receive(:invoke_actions).with(target, {:event => events[0]}, succeeded, failed)
        described_class.enforce_policy(target, events[0].name)
      end
    end
  end

  describe ".built_in_policies" do
    it 'creates built in policies' do
      policy = described_class.built_in_policies[0]
      %w(name description towhat active mode conditions).each do |m|
        expect(policy.send(m)).not_to be_nil
      end
      expect(policy.events).not_to                      be_empty
      expect(policy.actions_for_event).not_to           be_empty
      expect(policy.applies_to?(double, double)).not_to be_nil
    end
  end
end
