RSpec.describe EmsEvent do
  context "model" do
    let(:ems1) { FactoryBot.create(:ems_kubernetes) }
    let(:ems2) { FactoryBot.create(:ems_kubernetes) }

    it "Find ems events and generated events for ext management systems" do
      generated_event = FactoryBot.create(:ems_event, :ext_management_system => ems1, :generating_ems => ems2)
      expect(ems1.ems_events).to match_array([generated_event])
      expect(ems2.generated_events).to match_array([generated_event])
    end
  end

  context "container events" do
    let(:ems_ref) { "test_ems_ref" }
    let(:ems) { FactoryBot.create(:ems_kubernetes) }
    let(:event_hash) { {:ems_ref => "event-ref", :ems_id => ems.id, :event_type => "STUFF_HAPPENED"} }
    let(:container_project) { FactoryBot.create(:container_project, :ext_management_system => ems) }

    context "on node" do
      let(:node_event_hash) { event_hash.merge(:container_node_ems_ref => ems_ref) }
      let!(:container_node) { FactoryBot.create(:container_node, :ext_management_system => ems, :name => "Test Node", :ems_ref => ems_ref) }

      it "process_container_entities_in_event! links node id to event" do
        EmsEvent.process_container_entities_in_event!(node_event_hash)
        expect(node_event_hash[:container_node_id]).to eq container_node.id
      end

      it "process_container_entities_in_event! doesn't clear event ems_ref" do
        EmsEvent.process_container_entities_in_event!(node_event_hash)
        expect(node_event_hash[:ems_ref]).to eq "event-ref"
      end

      it "constructed event has .container_node" do
        event = EmsEvent.add(ems.id, node_event_hash)
        expect(event.container_node).to eq container_node
      end
    end

    context "on pod" do
      let(:pod_event_hash) { event_hash.merge(:container_group_ems_ref => ems_ref) }
      let!(:container_group) { FactoryBot.create(:container_group, :ext_management_system => ems, :container_project => container_project, :name => "Test Group", :ems_ref => ems_ref) }

      it "process_container_entities_in_event! links pod id to event" do
        EmsEvent.process_container_entities_in_event!(pod_event_hash)
        expect(pod_event_hash[:container_group_id]).to eq container_group.id
      end

      it "constructed event has .container_group" do
        event = EmsEvent.add(ems.id, pod_event_hash)
        expect(event.container_group).to eq container_group
      end
    end

    context "on replicator" do
      let(:repl_event_hash) { event_hash.merge(:container_replicator_ems_ref => ems_ref) }
      let!(:container_replicator) { FactoryBot.create(:container_replicator, :ext_management_system => ems, :container_project => container_project, :name => "Test Replicator", :ems_ref => ems_ref) }

      it "process_container_entities_in_event! links replicator id to event" do
        EmsEvent.process_container_entities_in_event!(repl_event_hash)
        expect(repl_event_hash[:container_replicator_id]).to eq container_replicator.id
      end

      it "constructed event has .container_replicator" do
        event = EmsEvent.add(ems.id, repl_event_hash)
        expect(event.container_replicator).to eq container_replicator
      end
    end
  end

  context "with availability zones" do
    let(:vm) { FactoryBot.create(:vm_openstack, :ems_ref => "vm1") }
    before do
      @zone = FactoryBot.create(:small_environment)
      @ems  = @zone.ext_management_systems.first
      @availability_zone = FactoryBot.create(:availability_zone_openstack, :ems_ref => "az1")
    end

    context ".process_availability_zone_in_event!" do
      let(:event_hash) { {:vm_or_template_id => vm.id} }
      context "when the event has an availability zone" do
        before do
          event_hash[:availability_zone_ems_ref] = @availability_zone.ems_ref
        end

        it "should use the availability zone from the event" do
          EmsEvent.process_availability_zone_in_event!(event_hash)
          expect(event_hash[:availability_zone_id]).to eq @availability_zone.id
        end
      end

      context "when the event has no availability zone" do
        context "and the VM has an availability zone" do
          before do
            vm.availability_zone_id = @availability_zone.id
            vm.save
          end

          it "should use the VM's availability zone" do
            EmsEvent.process_availability_zone_in_event!(event_hash)
            expect(event_hash[:availability_zone_id]).to eq @availability_zone.id
          end
        end

        context "and the VM does not have an availability zone" do
          it "should not put an availability zone in the event hash" do
            EmsEvent.process_availability_zone_in_event!(event_hash)
            expect(event_hash[:availability_zone_id]).to be_nil
          end
        end
      end
    end

    context ".add_queue" do
      let(:ems) { FactoryBot.create(:ems_kubernetes) }
      let(:event_hash) do
        {
          :ems_ref    => "event-ref",
          :ems_id     => ems.id,
          :event_type => "STUFF_HAPPENED"
        }
      end

      context "messaging_type: artemis, dequeue_method: miq_messaging" do
        before do
          stub_settings_merge(
            :messaging => {:type => 'artemis'},
            :workers   => {:worker_base => {:queue_worker_base => {:defaults => {:dequeue_method => "miq_messaging"}}}}
          )
        end

        it "Adds event to Artemis queue" do
          messaging_client = double("ManageIQ::Messaging")

          expected_queue_payload = {
            :service => "manageiq.ems",
            :sender  => ems.id,
            :event   => event_hash[:event_type],
            :payload => event_hash
          }

          expect(messaging_client).to receive(:publish_topic).with(expected_queue_payload)
          expect(MiqQueue).to receive(:messaging_client).with('event_handler').and_return(messaging_client).twice

          described_class.add_queue('add', ems.id, event_hash)
        end
      end

      context "messaging_type: artemis, dequeue_method: drb" do
        before do
          stub_settings_merge(
            :messaging => {:type => 'artemis'},
            :workers   => {:worker_base => {:queue_worker_base => {:event_handler => {:dequeue_method => "drb"}}}}
          )
        end

        it "Adds event to Kafka topic" do
          expected_queue_payload = {
            :service     => "event",
            :target_id   => ems.id,
            :class_name  => described_class.name,
            :method_name => 'add',
            :args        => [event_hash],
          }

          expect(MiqQueue).to receive(:submit_job).with(expected_queue_payload)

          described_class.add_queue('add', ems.id, event_hash)
        end
      end

      context "messaging_type: kafka, dequeue_method: miq_messaging" do
        before do
          stub_settings_merge(
            :messaging => {:type => 'kafka'},
            :workers   => {:worker_base => {:queue_worker_base => {:defaults => {:dequeue_method => "miq_messaging"}}}}
          )
        end

        it "Adds event to Kafka topic" do
          messaging_client = double("ManageIQ::Messaging")

          expected_queue_payload = {
            :service => "manageiq.ems",
            :sender  => ems.id,
            :event   => event_hash[:event_type],
            :payload => event_hash
          }

          expect(messaging_client).to receive(:publish_topic).with(expected_queue_payload)
          expect(MiqQueue).to receive(:messaging_client).with('event_handler').and_return(messaging_client).twice

          described_class.add_queue('add', ems.id, event_hash)
        end
      end

      context "messaging_type: kafka, dequeue_method: drb" do
        before do
          stub_settings_merge(
            :messaging => {:type => 'kafka'},
            :workers   => {:worker_base => {:queue_worker_base => {:event_handler => {:dequeue_method => "drb"}}}}
          )
        end

        it "Adds event to Kafka topic" do
          expected_queue_payload = {
            :service     => "event",
            :target_id   => ems.id,
            :class_name  => described_class.name,
            :method_name => 'add',
            :args        => [event_hash],
          }

          expect(MiqQueue).to receive(:submit_job).with(expected_queue_payload)

          described_class.add_queue('add', ems.id, event_hash)
        end
      end

      context "messaging_type: miq_queue" do
        before { stub_settings_merge(:messaging => {:type => 'miq_queue'}) }

        it "Adds event to MiqQueue" do
          expected_queue_payload = {
            :service     => "event",
            :target_id   => ems.id,
            :class_name  => described_class.name,
            :method_name => 'add',
            :args        => [event_hash],
          }

          expect(MiqQueue).to receive(:messaging_client).with('event_handler').and_return(nil)
          expect(MiqQueue).to receive(:submit_job).with(expected_queue_payload)

          described_class.add_queue('add', ems.id, event_hash)
        end
      end
    end

    context ".add" do
      before do
        @event_hash = {
          :event_type  => "event_with_availability_zone",
          :target_type => vm.class.name,
          :target_id   => vm.id,
          :ems_ref     => "first",
          :vm_ems_ref  => vm.ems_ref,
          :timestamp   => Time.now,
          :ems_id      => @ems.id
        }
      end

      context "when the event does not have an availability zone" do
        it "should create an event record with the VMs availability zone" do
          vm.availability_zone_id = @availability_zone.id
          vm.save

          new_event = EmsEvent.add(vm.ems_id, @event_hash)
          expect(new_event.availability_zone_id).to eq @availability_zone.id
        end
      end

      context "when the event does contain an availability zone" do
        it "should use the availability zone from the event" do
          @event_hash[:availability_zone_ems_ref] = @availability_zone.ems_ref
          vm.availability_zone_id = nil
          vm.save

          new_event = EmsEvent.add(vm.ems_id, @event_hash)
          expect(new_event.availability_zone_id).to eq @availability_zone.id
        end
      end

      context "when an event was previously added" do
        before do
          EmsEvent.add(@ems.id, @event_hash)
        end

        it "should reject duplicates" do
          ems_event = EmsEvent.add(@ems.id, @event_hash)
          expect(
            EmsEvent.where(@event_hash.except(:ems_ref)).count
          ).to eq(1)
          expect(ems_event).to be_nil
        end

        context "with event syndication" do
          before do
            stub_settings_merge(:event_streams => {:syndicate_events => true})
          end

          it "doesn't syndicate duplicate events" do
            expect(EmsEvent).not_to receive(:syndicate_event)

            ems_event = EmsEvent.add(@ems.id, @event_hash)
            expect(ems_event).to be_nil
          end
        end

        it "should add a new event if it has a different ems_ref" do
          ems_event = EmsEvent.add(
            @ems.id,
            @event_hash.merge(:ems_ref => "second")
          )
          expect(
            EmsEvent.where(@event_hash.except(:ems_ref)).count
          ).to eq(2)
          expect(ems_event).to_not be_nil
        end
      end
    end
  end

  context ".add" do
    let(:ems) { FactoryBot.create(:ext_management_system) }
    context "with a VM" do
      let(:vm) { FactoryBot.create(:vm, :uid_ems => '3ace5197-3d6a-4cb3-aeb2-e8348e428775', :ems_ref => 'vm-123') }
      let(:event) do
        {
          :ems_id     => ems.id,
          :event_type => 'VmDestroyedEvent',
          :vm_ems_ref => vm.ems_ref,
          :vm_uid_ems => vm.uid_ems,
        }
      end

      context "with a connected VM" do
        before { vm.update(:ems_id => ems.id) }

        it "should link the event to the vm" do
          ems_event = EmsEvent.add(ems.id, event)
          expect(ems_event.vm_or_template_id).to eq(vm.id)
        end
      end

      context "with a disconnected VM" do
        it "should link the event to the vm" do
          ems_event = EmsEvent.add(ems.id, event)
          expect(ems_event.vm_or_template_id).to eq(vm.id)
        end
      end
    end

    context "with a host" do
      let(:event) do
        {
          :ems_id       => ems.id,
          :event_type   => "HostAddEvent",
          :host_uid_ems => host.uid_ems
        }
      end

      context "with an active host" do
        let(:host) { FactoryBot.create(:host, :uid_ems => "6f3fa3f1-bbe0-4aab-9a69-5d652324357f", :ext_management_system => ems) }

        it "should link the event to the host" do
          ems_event = described_class.add(ems.id, event)
          expect(ems_event.host).to eq(host)
        end
      end

      context "with an archived host" do
        let(:host) { FactoryBot.create(:host, :uid_ems => "6f3fa3f1-bbe0-4aab-9a69-5d652324357f") }

        it "should link the event to the host" do
          ems_event = described_class.add(ems.id, event)
          expect(ems_event.host).to eq(host)
        end
      end

      context "with active and archived hosts with the same uid_ems" do
        let!(:archived_host) { FactoryBot.create(:host, :uid_ems => "6f3fa3f1-bbe0-4aab-9a69-5d652324357f") }
        let!(:host)          { FactoryBot.create(:host, :uid_ems => "6f3fa3f1-bbe0-4aab-9a69-5d652324357f", :ext_management_system => ems) }

        it "should prefer the active host" do
          ems_event = described_class.add(ems.id, event)
          expect(ems_event.host).to eq(host)
        end
      end
    end
  end

  # NOTE: Do not use Settings stubs here (e.g. stub_settings_merge), as this test is meant to
  # test the actual Settings across all providers.
  describe ".event_groups (actual Settings)" do
    described_class.event_groups.each do |group_name, group_data|
      described_class.group_levels.each do |level|
        group_data[level]&.each do |typ|
          it ":#{group_name}/:#{level}/#{typ} is string or regex", :providers_common => true do
            expect(typ.kind_of?(Regexp) || typ.kind_of?(String)).to eq(true)
          end

          if typ.kind_of?(Regexp)
            it ":#{group_name}/:#{level}/#{typ} is usable in SQL queries", :providers_common => true do
              expect { described_class.where("event_type ~ ?", typ.source).to_a }
                .to_not raise_error
            end

            it ":#{group_name}/:#{level}/#{typ} only uses case insensitivity option", :providers_common => true do
              expect(typ.options & (Regexp::EXTENDED | Regexp::MULTILINE)).to eq(0)
            end
          end
        end
      end
    end
  end

  context '.event_groups' do
    before(:each) do
      stub_settings_merge(
        :ems => {
          :some_provider => {
            :event_handling => {
              :event_groups => {
                :power => {
                  :warning  => [provider_warning_event],
                  :critical => [provider_critical_event],
                  :detail   => [provider_detail_event],
                }
              }
            }
          }
        }
      )
    end

    let(:provider_critical_event) { 'SomeCriticalEvent' }
    let(:provider_detail_event) { 'SomeDetailEvent' }
    let(:provider_warning_event) { 'SomeWarningEvent' }

    it 'returns a list of expected groups' do
      event_group_names = [
        :addition,
        :configuration,
        :console,
        :deletion,
        :devices,
        :firmware,
        :general,
        :import_export,
        :login,
        :migration,
        :network,
        :power,
        :security,
        :snapshot,
        :status,
        :storage,
        :update,
      ]
      expect(described_class.event_groups.keys).to match_array(event_group_names)
      expect(described_class.event_groups[:addition]).to include(:name => 'Creation/Addition')
      expect(described_class.event_groups[:addition][:critical]).to include('CloneTaskEvent')
      expect(described_class.event_groups[:addition][:critical]).not_to include('BogueEvent')
    end

    it 'returns the group, level and group name of an unknown event' do
      group, level = described_class.group_and_level('BogusEvent')
      expect(group).to eq(:other)
      expect(level).to eq(:detail)
      expect(described_class.group_name(group)).to eq('Other')
    end

    it 'returns the group, level and group name of a warning event' do
      group, level = described_class.group_and_level(provider_warning_event)
      expect(group).to eq(:power)
      expect(level).to eq(:warning)
      expect(described_class.group_name(group)).to eq('Power Activity')
    end

    it 'returns the group, level and group name of a critical event' do
      group, level = described_class.group_and_level(provider_critical_event)
      expect(group).to eq(:power)
      expect(level).to eq(:critical)
      expect(described_class.group_name(group)).to eq('Power Activity')
    end

    it 'returns the group, level and group name of a detail event' do
      group, level = described_class.group_and_level(provider_detail_event)
      expect(group).to eq(:power)
      expect(level).to eq(:detail)
      expect(described_class.group_name(group)).to eq('Power Activity')
    end

    context 'with provider events' do
      before(:each) do
        stub_settings_merge(
          :ems => {
            :some_provider => {
              :event_handling => {
                :event_groups => {
                  :addition => {
                    :warning  => [provider_regex],
                    :critical => [provider_event]
                  }
                }
              }
            }
          }
        )
      end

      let(:provider_event) { 'SomeSpecialProviderEvent' }
      let(:provider_regex) { "/Some.+Event/" }

      it 'returns the provider event if configured' do
        expect(described_class.event_groups[:addition][:critical]).to include('CloneTaskEvent')
        expect(described_class.event_groups[:addition][:critical]).to include(provider_event)
        expect(described_class.event_groups[:addition][:warning]).to include(provider_regex)
      end

      # Make sure explicitly named event types take precedence over regex
      it 'returns the group, level and group name of a warning event' do
        group, level = described_class.group_and_level(provider_warning_event)
        expect(group).to eq(:power)
        expect(level).to eq(:warning)
        expect(described_class.group_name(group)).to eq('Power Activity')
      end

      it 'returns the group, level and group name of a critical event' do
        group, level = described_class.group_and_level(provider_critical_event)
        expect(group).to eq(:power)
        expect(level).to eq(:critical)
        expect(described_class.group_name(group)).to eq('Power Activity')
      end

      it 'returns the group, level and group name of a detail event' do
        group, level = described_class.group_and_level(provider_detail_event)
        expect(group).to eq(:power)
        expect(level).to eq(:detail)
        expect(described_class.group_name(group)).to eq('Power Activity')
      end
      # End make sure explicitly named event types take precedence over regex

      it 'returns the group, level and group name of a regex-matched event' do
        group, level = described_class.group_and_level('SomeMatchingEvent')
        expect(group).to eq(:addition)
        expect(level).to eq(:warning)
        expect(described_class.group_name(group)).to eq('Creation/Addition')
      end

      it 'returns the group, level and group name of an unknown event' do
        group, level = described_class.group_and_level('BogusEvent')
        expect(group).to eq(:other)
        expect(level).to eq(:detail)
        expect(described_class.group_name(group)).to eq('Other')
      end
    end
  end

  it "group_names_and_levels" do
    result = described_class.group_names_and_levels
    expect(result.keys).to match_array(%i[description group_names group_levels])
    expect(result[:description]).to eq("Management Events")
    expect(result[:group_names].keys).to include(:other)
  end

  context 'refresh target' do
    describe 'src_vm_or_dest_host_refresh_target' do
      let(:ems)   { FactoryBot.create(:ems_vmware) }
      let(:vm)    { FactoryBot.create(:vm_vmware, :ext_management_system => ems) }
      let(:host1) { FactoryBot.create(:host, :ext_management_system => ems) }
      let(:host2) { FactoryBot.create(:host, :ext_management_system => ems) }

      it 'returns src_vm when it exists' do
        event = FactoryBot.create(:ems_event, :vm_or_template => vm, :host => host1, :dest_host => host2)
        expect(event.get_target("src_vm_or_dest_host_refresh_target")).to eq(vm)
      end

      it 'returns dest_host when src_vm does not exists' do
        event = FactoryBot.create(:ems_event, :vm_or_template_id => 123, :host => host1, :dest_host => host2)
        expect(event.get_target("src_vm_or_dest_host_refresh_target")).to eq(host2)
      end
    end
  end

  describe '#manager_refresh' do
    let(:ems)       { FactoryBot.create(:ems_cloud) }
    let(:ems_event) do
      FactoryBot.create(
        :ems_event,
        :ext_management_system => ems,
        :event_type            => "CloneVM_Task",
        :full_data             => {"info" => {"task" => "task-5324"}}
      )
    end

    context "targeted refresh supported" do
      let(:target_parser) { double("EventTargetParser") }

      before do
        allow(ems).to receive(:allow_targeted_refresh?).and_return(true)
        allow(ems.class.const_get(:EventTargetParser)).to receive(:new).and_return(target_parser)
        expect(target_parser).to receive(:parse).and_return(targets)
      end

      context "with no targets" do
        let(:targets) { [] }

        it "skips queuing the refresh" do
          expect(EmsRefresh).not_to receive(:queue_refresh)
          ems_event.manager_refresh
        end
      end

      context "with targets" do
        let(:targets) { [InventoryRefresh::Target.new(:manager => ems, :association => :vms, :manager_ref => {:ems_ref => "1234"})] }

        it "performs a targeted refresh" do
          expect(EmsRefresh).to receive(:queue_refresh).with(targets, any_args)
          ems_event.manager_refresh
        end
      end
    end

    context "targeted refresh not supported" do
      before { allow(ems).to receive(:allow_targeted_refresh?).and_return(false) }

      it "runs a full refresh" do
        expect(EmsRefresh).to receive(:queue_refresh).with(ems, any_args)
        ems_event.manager_refresh
      end
    end
  end

  context 'Physical Storage Events' do
    let(:ems)   { FactoryBot.create(:ems_storage) }
    let(:physical_storage) { FactoryBot.create(:physical_storage, :name => "my-storage", :ems_ref => "ems1", :ext_management_system => ems) }
    let(:event_hash) do
      {
        :event_type               => "physical_storage_alert",
        :ems_ref                  => "1",
        :physical_storage_ems_ref => physical_storage.ems_ref,
        :ems_id                   => ems.id,
        :message                  => "description"
      }
    end

    it "test process_physical_storage_in_event!" do
      event = EmsEvent.add(ems.id, event_hash)
      expect(event.attributes.keys).to include('physical_storage_id', 'physical_storage_name')
      expect(event.physical_storage_id).to eq(physical_storage.id)
      expect(event.physical_storage_name).to eq(physical_storage.name)
    end
  end
end
