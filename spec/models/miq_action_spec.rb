describe MiqAction do
  describe "#invoke_or_queue" do
    before(:each) do
      @action = MiqAction.new
    end

    it "executes synchronous actions" do
      target = double("action")
      allow(target).to receive(:target_method)
      @action.instance_eval { invoke_or_queue(true, "__caller__", "role", nil, target, 'target_method', []) }
    end
  end

  context "#action_custom_automation" do
    before(:each) do
      tenant = FactoryGirl.create(:tenant)
      group  = FactoryGirl.create(:miq_group, :tenant => tenant)
      @user = FactoryGirl.create(:user, :userid => "test", :miq_groups => [group])
      @vm   = FactoryGirl.create(:vm_vmware, :evm_owner => @user, :miq_group => group)
      FactoryGirl.create(:miq_action, :name => "custom_automation")
      @action = MiqAction.find_by(:name => "custom_automation")
      expect(@action).not_to be_nil
      @action.options = {:ae_request => "test_custom_automation"}
      @args = {
        :object_type      => @vm.class.base_class.name,
        :object_id        => @vm.id,
        :user_id          => @vm.evm_owner.id,
        :miq_group_id     => @vm.miq_group.id,
        :tenant_id        => @vm.tenant.id,
        :attrs            => {:request => "test_custom_automation"},
        :instance_name    => "REQUEST",
        :automate_message => "create"
      }
    end

    it "synchronous" do
      expect(MiqAeEngine).to receive(:deliver).with(@args).once
      @action.action_custom_automation(@action, @vm, :synchronous => true)
    end

    it "asynchronous" do
      expect(MiqAeEngine).to receive(:deliver).never

      q_options = {
        :class_name  => 'MiqAeEngine',
        :method_name => 'deliver',
        :args        => [@args],
        :role        => 'automate',
        :zone        => nil,
        :priority    => MiqQueue::HIGH_PRIORITY,
      }
      expect(MiqQueue).to receive(:put).with(q_options).once
      @action.action_custom_automation(@action, @vm, :synchronous => false)
    end

    it "passes source event to automate if set" do
      ems_event = FactoryGirl.create(:ems_event, :event_type => "CloneVM_Task")
      args = {:attrs => {:request => "test_custom_automation", "EventStream::event_stream" => ems_event.id}}
      expect(MiqAeEngine).to receive(:deliver).with(hash_including(args)).once

      @action.action_custom_automation(@action, @vm, :synchronous => true, :source_event => ems_event)
    end
  end

  context "#action_evm_event" do
    it "for Vm" do
      ems = FactoryGirl.create(:ems_vmware)
      host = FactoryGirl.create(:host_vmware)
      vm = FactoryGirl.create(:vm_vmware, :host => host, :ext_management_system => ems)
      action = FactoryGirl.create(:miq_action)
      res = action.action_evm_event(action, vm, :policy => FactoryGirl.create(:miq_policy))

      expect(res).to be_kind_of(MiqEvent)
      expect(res.target).to eq(vm)
    end

    it "for Datastore" do
      storage = FactoryGirl.create(:storage)
      action  = FactoryGirl.create(:miq_action)
      result  = action.action_evm_event(action, storage, :policy => FactoryGirl.create(:miq_policy))

      expect(result).to be_kind_of(MiqEvent)
      expect(result.target).to eq(storage)
    end
  end

  context "#raise_automation_event" do
    before(:each) do
      @vm   = FactoryGirl.create(:vm_vmware)
      allow(@vm).to receive(:my_zone).and_return("vm_zone")
      FactoryGirl.create(:miq_event_definition, :name => "raise_automation_event")
      FactoryGirl.create(:miq_event_definition, :name => "vm_start")
      FactoryGirl.create(:miq_action, :name => "raise_automation_event")
      @action = MiqAction.find_by(:name => "raise_automation_event")
      expect(@action).not_to be_nil
      @event = MiqEventDefinition.find_by(:name => "vm_start")
      expect(@event).not_to be_nil
      @aevent = {
        :vm     => @vm,
        :host   => nil,
        :ems    => nil,
        :policy => @policy,
      }
    end

    it "synchronous" do
      expect(MiqAeEvent).to receive(:raise_synthetic_event).with(@vm, @event.name, @aevent).once
      expect(MiqQueue).to receive(:put).never
      @action.action_raise_automation_event(@action, @vm, :vm => @vm, :event => @event, :policy => @policy, :synchronous => true)
    end

    it "synchronous, not passing vm in inputs hash" do
      expect(MiqAeEvent).to receive(:raise_synthetic_event).with(@vm, @event.name, @aevent).once
      expect(MiqQueue).to receive(:put).never
      @action.action_raise_automation_event(@action, @vm, :vm => nil, :event => @event, :policy => @policy, :synchronous => true)
    end

    it "asynchronous" do
      expect(MiqAeEvent).to receive(:raise_synthetic_event).never
      q_options = {
        :class_name  => "MiqAeEvent",
        :method_name => "raise_synthetic_event",
        :args        => [@vm, @event.name, @aevent],
        :priority    => MiqQueue::HIGH_PRIORITY,
        :zone        => "vm_zone",
        :role        => "automate"
      }
      expect(MiqQueue).to receive(:put).with(q_options).once
      @action.action_raise_automation_event(@action, @vm, :vm => @vm, :event => @event, :policy => @policy, :synchronous => false)
    end
  end

  context "#action_ems_refresh" do
    before(:each) do
      FactoryGirl.create(:miq_action, :name => "ems_refresh")
      @action = MiqAction.find_by(:name => "ems_refresh")
      expect(@action).not_to be_nil
      @zone1 = FactoryGirl.create(:small_environment)
      @vm = @zone1.vms.first
    end

    it "synchronous" do
      expect(EmsRefresh).to receive(:refresh).with(@vm).once
      expect(EmsRefresh).to receive(:queue_refresh).never
      @action.action_ems_refresh(@action, @vm, {:vm => @vm, :policy => @policy, :event => @event, :synchronous => true})
    end

    it "asynchronous" do
      expect(EmsRefresh).to receive(:refresh).never
      expect(EmsRefresh).to receive(:queue_refresh).with(@vm).once
      @action.action_ems_refresh(@action, @vm, {:vm => @vm, :policy => @policy, :event => @event, :synchronous => false})
    end
  end

  context "#action_vm_retire" do
    before do
      @vm     = FactoryGirl.create(:vm_vmware)
      allow(@vm).to receive(:my_zone).and_return("vm_zone")
      @event  = FactoryGirl.create(:miq_event_definition, :name => "assigned_company_tag")
      @action = FactoryGirl.create(:miq_action, :name => "vm_retire")
    end

    it "synchronous" do
      input  = {:synchronous => true}

      Timecop.freeze do
        date   = Time.now.utc - 1.day

        expect(VmOrTemplate).to receive(:retire) do |vms, options|
          expect(vms).to eq([@vm])
          expect(options[:date]).to be_same_time_as date
        end
        @action.action_vm_retire(@action, @vm, input)
      end
    end

    it "asynchronous" do
      input = {:synchronous => false}
      zone  = 'Test Zone'
      allow(@vm).to receive_messages(:my_zone => zone)

      Timecop.freeze do
        date   = Time.now.utc - 1.day

        @action.action_vm_retire(@action, @vm, input)
        expect(MiqQueue.count).to eq(1)
        msg = MiqQueue.first
        expect(msg.class_name).to eq(@vm.class.name)
        expect(msg.method_name).to eq('retire')
        expect(msg.args).to eq([[@vm], :date => date])
        expect(msg.zone).to eq(zone)
      end
    end
  end

  context "#action_container_image_analyze" do
    let(:container_image) { FactoryGirl.create(:container_image) }
    let(:container_image_registry) { FactoryGirl.create(:container_image_registry) }
    let(:event) { FactoryGirl.create(:miq_event_definition, :name => "whatever") }
    let(:event_loop) { FactoryGirl.create(:miq_event_definition, :name => "request_containerimage_scan") }
    let(:action) { FactoryGirl.create(:miq_action, :name => "container_image_analyze") }

    it "scans container images" do
      expect(container_image).to receive(:scan).once
      action.action_container_image_analyze(action, container_image, :event => event)
    end

    it "avoids non container images" do
      expect(container_image_registry).to receive(:scan).exactly(0).times
      action.action_container_image_analyze(action, container_image_registry, :event => event)
    end

    it "avoids an event loop" do
      expect(container_image_registry).to receive(:scan).exactly(0).times
      action.action_container_image_analyze(action, container_image_registry, :event => event_loop)
    end
  end

  context '.create_default_actions' do
    context 'seeding default actions from a file with 3 csv rows and some comments' do
      before do
        stub_csv <<-CSV.strip_heredoc
          name,description
          audit,Generate Audit Event
          log,Generate log message
          # snmp,Generate an SNMP trap
          # sms,Send an SMS text message
          evm_event,Show EVM Event on Timeline
        CSV

        MiqAction.create_default_actions
      end

      it 'should create 3 new actions' do
        expect(MiqAction.count).to eq 3
      end

      it 'should set action_type to "default"' do
        expect(MiqAction.distinct.pluck(:action_type)).to eq ['default']
      end

      context 'when csv was changed and imported again' do
        before do
          stub_csv <<-CSV.strip_heredoc
            name,description
            audit,UPD: Audit Event
            # log,Generate log message
            snmp,Generate an SNMP trap
            evm_event,Show EVM Event on Timeline
          CSV

          MiqAction.create_default_actions
        end

        it "should not delete the actions that present in the DB but don't present in the file" do
          expect(MiqAction.where(:name => 'log')).to exist
        end

        it 'should update existing actions' do
          expect(MiqAction.where(:name => 'audit').pluck(:description)).to eq ['UPD: Audit Event']
        end

        it 'should create new actions' do
          expect(MiqAction.where(:name => 'snmp')).to exist
        end
      end

      def stub_csv(data)
        Tempfile.open(['actions', '.csv']) do |f|
          f.write(data)
          @tempfile = f # keep the reference in order to delete the file later
        end

        expect(MiqAction).to receive(:fixture_path).and_return(@tempfile.path)
      end

      after do
        @tempfile.unlink
      end
    end

    # 'integration' test to make sure that the real fixture file is well-formed
    context 'seeding default actions' do
      before { MiqAction.create_default_actions }

      it 'should create new actions' do
        expect(MiqAction.count).to be > 0
      end
    end
  end

  context '.create_script_actions_from_directory' do
    context 'when there are 3 files in the script directory' do
      before do
        @script_dir = Dir.mktmpdir
        stub_const('::MiqAction::SCRIPT_DIR', Pathname(@script_dir))
        FileUtils.touch %W(
          #{@script_dir}/script2.rb
          #{@script_dir}/script.1.sh
          #{@script_dir}/script3
        )
      end

      after do
        FileUtils.remove_entry_secure @script_dir
      end

      context 'seeding script actions from that directory' do
        before { MiqAction.create_script_actions_from_directory }
        let(:first_created_action) { MiqAction.order(:id).first! }

        it 'should create 3 new actions' do
          expect(MiqAction.count).to eq 3
        end

        it 'should assign script filename as action name' do
          expect(first_created_action.name).to eq 'script_1_sh'
        end

        it 'should set action_type to "script"' do
          expect(MiqAction.distinct.pluck(:action_type)).to eq ['script']
        end

        it 'should add description' do
          expect(first_created_action.description).to eq "Execute script: script.1.sh"
        end

        it 'should put full file path into options hash' do
          expect(first_created_action.options).to eq(:filename => "#{@script_dir}/script.1.sh")
        end

        context 'after one of the scripts is renamed' do
          before { FileUtils.mv("#{@script_dir}/script2.rb", "#{@script_dir}/run.bat") }

          context 'seeding script actions again' do
            before { MiqAction.create_script_actions_from_directory }

            it 'should not delete the old action' do
              expect(MiqAction.where(:name => 'script2_rb')).to exist
            end

            it 'should create a new action' do
              expect(MiqAction.where(:name => 'run_bat')).to exist
            end
          end
        end

        context 'seeding script actions again' do
          before { MiqAction.create_script_actions_from_directory }

          it 'should not add any new actions' do
            expect(MiqAction.count).to eq 3
          end
        end
      end
    end
  end

  context '#round_to_nearest_4mb' do
    it 'should round numbers to nearest 4 mb' do
      a = MiqAction.new

      expect(a.round_to_nearest_4mb(0)).to eq 0
      expect(a.round_to_nearest_4mb("2")).to eq 4
      expect(a.round_to_nearest_4mb(15)).to eq 16
      expect(a.round_to_nearest_4mb(16)).to eq 16
      expect(a.round_to_nearest_4mb(17)).to eq 20
    end
  end

  context 'validate action email should have correct type' do
    it 'should generate a MiqAction invoking action_email' do
      action = MiqAction.new
      inputs = {
        :policy      => nil,
        :synchronous => false
      }
      q_options = {
        :class_name  => "MiqAction",
        :method_name => "queue_email",
        :args        => [{:to => nil, :from => "cfadmin@cfserver.com"}],
        :role        => "notifier",
        :priority    => 20,
        :zone        => nil
      }
      expect(MiqQueue).to receive(:put).with(q_options).once
      action.action_email(action, nil, inputs)
    end
  end
end
