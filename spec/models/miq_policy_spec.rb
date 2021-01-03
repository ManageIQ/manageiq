RSpec.describe MiqPolicy do
  it "doesn't access database when unchanged model is saved" do
    m = FactoryBot.create(:miq_policy)
    expect { m.valid? }.not_to make_database_queries
  end

  context "Testing edge cases on conditions" do
    # The conditions reflection on MiqPolicy is affected when called through a
    # belongs_to or has_one, which is used under the covers in MiqSet.  This
    # test verifies that changing things under the covers doesn't affect
    # calling conditions.

    before do
      @ps = FactoryBot.create(:miq_policy_set, :name => "ps")
      @p  = FactoryBot.create(:miq_policy)
      @ps.add_member(@p)

      @ps2 = FactoryBot.create(:miq_policy_set, :name => "ps2")
      @p2  = FactoryBot.create(:miq_policy)
    end

    it "should return the correct conditions" do
      expect(@ps.miq_policies.first.conditions).to eq([])
      expect(@p.conditions).to eq([])
    end
  end

  context "#description=" do
    subject { FactoryBot.create(:miq_policy, :description => @description) }

    it "should keep the description < 255" do
      @description = "a" * 30
      expect(subject.description.length).to eq(30)
    end

    it "should raise an error with empty description" do
      @description = nil
      expect { subject.description }.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: MiqPolicy: Description can't be blank")
    end

    it "should raise an error when description is reset to empty" do
      @description = "a" * 30
      subject.description = nil
      expect { subject.save! }.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: MiqPolicy: Description can't be blank")
    end
  end

  context "instance methods" do
    let(:event)  { FactoryBot.create(:miq_event_definition) }
    let(:action) { FactoryBot.create(:miq_action) }

    let(:policy) do
      cond = FactoryBot.create(:condition)
      FactoryBot.create(:miq_policy, :conditions => [cond]).tap do |p|
        p.replace_actions_for_event(event, [[action, {:qualifier => :success}]])
      end
    end

    describe "#events" do
      it "lists miq_event_definition assigned to the policy" do
        expect(policy.events).to eq([event])
      end
    end

    describe '#miq_event_definitions' do
      before do
        policy.miq_policy_contents.push(FactoryBot.create(:miq_policy_content))
      end

      it 'lists event definition' do
        expect(policy.miq_event_definitions).to eq([event])
      end
    end

    describe "#sync_events, #add_event, #delete_event" do
      let(:new_events) { [FactoryBot.create(:miq_event_definition), FactoryBot.create(:miq_event_definition)] }

      it 'synchronizes with new list of events' do
        policy.sync_events(new_events)
        policy.reload
        expect(policy.events).to eq(new_events)
      end
    end

    describe "#actions #actions_for_event, #replace_actions_for_event" do
      let(:new_action)    { FactoryBot.create(:miq_action) }
      let(:another_event) { FactoryBot.create(:miq_event_definition) }

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
      let(:target_vm)       { FactoryBot.create(:vm_amazon) }
      let(:target_template) { FactoryBot.create(:template_infra) }
      let(:target_host)     { FactoryBot.create(:host) }

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
    let(:events)  { [FactoryBot.create(:miq_event_definition), FactoryBot.create(:miq_event_definition)] }
    let(:actions) { [FactoryBot.create(:miq_action), FactoryBot.create(:miq_action)] }
    let(:conds)   { [FactoryBot.create(:condition), FactoryBot.create(:condition)] }
    let(:target)  { FactoryBot.create(:vm) }

    let(:policies) do
      [
        FactoryBot.create(:miq_policy, :conditions => [conds[0]], :active => true, :mode => 'control').tap do |p|
          p.replace_actions_for_event(events[0], [[actions[0], {:qualifier => :success}], [actions[1], {:qualifier => :failure}]])
        end,
        FactoryBot.create(:miq_policy, :conditions => [conds[1]], :active => false).tap do |p|
          p.replace_actions_for_event(events[1], [[actions[1], {:qualifier => :success}]])
        end
      ]
    end

    let(:profiles) do
      [
        FactoryBot.create(:miq_policy_set, :name => "ps3").tap { |pf| pf.add_member(policies[0]) },
        FactoryBot.create(:miq_policy_set, :name => "ps4").tap { |pf| pf.add_member(policies[1]) },
      ]
    end

    before { policies }

    describe ".resolve" do
      it "resolves all policies" do
        results = described_class.resolve(FactoryBot.create(:vm))
        expect(results.size).to eq(2)
      end

      it "resolves policies by event" do
        results = described_class.resolve(FactoryBot.create(:vm), policies.collect(&:name), events[1])
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

    describe "#miq_policies (virtual_has_many)" do
      before { profiles }

      it "gets the policies under a profile" do
        expect(MiqPolicySet.find_by(:name => "ps3").miq_policies).to match_array([policies[0]])
        expect(MiqPolicySet.find_by(:name => "ps4").miq_policies).to match_array([policies[1]])
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

    describe ".eval_condition" do
      it "returns 'allow' when condition is met" do
        vm = FactoryBot.create(:vm_vmware, :hardware => FactoryBot.create(:hardware, :cpu_sockets => 2))
        result = described_class.send(:eval_condition, conds[0], vm)

        expect(result).to eq('allow')
      end

      it "returns 'deny' when condition is not met" do
        result = described_class.send(:eval_condition, conds[0], target)
        expect(result).to eq('deny')
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

  describe "(Built-in) Prevent Retired Instance from Starting policy" do
    before do
      FactoryBot.create(:miq_event_definition, :name => "vm_resume")
      FactoryBot.create(:miq_action, :name => "vm_suspend", :action_type => 'default')
      MiqPolicy.class_variable_set(:@@built_in_policies, nil)
      @vm = FactoryBot.create(:vm_openstack,
                               :ext_management_system => FactoryBot.create(:ems_openstack,
                                                                            :zone => FactoryBot.create(:zone)))
    end
    subject { MiqPolicy.enforce_policy(@vm, "vm_resume", {}) }

    it 'prevents retired instance from starting' do
      MiqQueue.destroy_all
      @vm.update(:retired => true)
      expect(subject[:result]).to be true
      expect(subject[:actions].size).to eq(1)
      expect(subject[:details].first["name"]).to eq("(Built-in) Prevent Retired Instance from Starting")
      q = MiqQueue.first
      expect(q.method_name).to eq('suspend')
      expect(q.class_name).to  eq(@vm.class.name)
      expect(q.instance_id).to eq(@vm.id)
    end

    it 'allows active vm to start' do
      expect(subject[:result]).to be false
      expect(subject[:actions].size).to eq(0)
      expect(subject[:details].first["name"]).to eq("(Built-in) Prevent Retired Instance from Starting")
    end
  end

  context '.default_value_for' do
    it 'sets defaults' do
      expect(described_class.create!(:description => 'x')).to have_attributes(
        :towhat => "Vm",
        :active => true,
        :mode   => "control",
      )
    end

    it 'allows override of defaults' do
      expect(described_class.create!(
        :towhat => "Host", :mode => "compliance", :active => false, :description => 'x',
      )).to have_attributes(
        :towhat => "Host",
        :active => false,
        :mode   => "compliance",
      )
    end
  end

  context '.validates' do
    it 'validates towhat' do
      expect(FactoryBot.build(:miq_policy, :towhat => "Host")).to be_valid
    end

    it 'reports invalid towhat' do
      policy = FactoryBot.build(:miq_policy, :towhat => "BobsYourUncle")
      towhat_error = "should be one of ContainerGroup, ContainerImage, "\
                     "ContainerNode, ContainerProject, ContainerReplicator, "\
                     "ExtManagementSystem, Host, PhysicalServer, Vm"

      expect(policy).not_to be_valid
      expect(policy.errors.messages).to include(:towhat => [towhat_error])
    end
  end
end
