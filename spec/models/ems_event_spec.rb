describe EmsEvent do
  context "model" do
    let(:ems1) { FactoryGirl.create(:ems_kubernetes) }
    let(:ems2) { FactoryGirl.create(:ems_kubernetes) }

    it "Find ems events and generated events for ext management systems" do
      generated_event = FactoryGirl.create(:ems_event, :ext_management_system => ems1, :generating_ems => ems2)
      expect(ems1.ems_events).to match_array([generated_event])
      expect(ems2.generated_events).to match_array([generated_event])
    end
  end

  context "container events" do
    let(:ems_ref) { "test_ems_ref" }
    let(:ems) { FactoryGirl.create(:ems_kubernetes) }
    let(:event_hash) { { :ems_ref => "event-ref", :ems_id => ems.id, :event_type => "STUFF_HAPPENED" } }
    let(:container_project) { FactoryGirl.create(:container_project, :ext_management_system => ems) }

    context "on node" do
      let(:node_event_hash) { event_hash.merge(:container_node_ems_ref => ems_ref) }
      let!(:container_node) { FactoryGirl.create(:container_node, :ext_management_system => ems, :name => "Test Node", :ems_ref => ems_ref) }

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
      let!(:container_group) { FactoryGirl.create(:container_group, :ext_management_system => ems, :container_project => container_project, :name => "Test Group", :ems_ref => ems_ref) }

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
      let!(:container_replicator) { FactoryGirl.create(:container_replicator, :ext_management_system => ems, :container_project => container_project, :name => "Test Replicator", :ems_ref => ems_ref) }

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
    let(:vm) { FactoryGirl.create(:vm_openstack, :ems_ref => "vm1") }
    before do
      @zone = FactoryGirl.create(:small_environment)
      @ems  = @zone.ext_management_systems.first
      @availability_zone = FactoryGirl.create(:availability_zone_openstack, :ems_ref => "az1")
    end

    context ".process_availability_zone_in_event!" do
      let(:event_hash) { { :vm_or_template_id => vm.id } }
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
      let(:ems) { FactoryGirl.create(:ems_kubernetes) }
      let(:event_hash) do
        {
          :ems_ref    => "event-ref",
          :ems_id     => ems.id,
          :event_type => "STUFF_HAPPENED"
        }
      end

      context "queue_type: artemis" do
        before { stub_settings_merge(:prototype => {:queue_type => 'artemis'}) }

        it "Adds event to Artemis queue" do
          queue_client = double("ManageIQ::Messaging")

          expected_queue_payload = {
            :service => "events",
            :sender  => ems.id,
            :event   => event_hash[:event_type],
            :payload => event_hash,
          }

          expect(queue_client).to receive(:publish_topic).with(expected_queue_payload)
          expect(MiqQueue).to receive(:artemis_client).with('event_handler').and_return(queue_client)

          described_class.add_queue('add', ems.id, event_hash)
        end
      end

      context "queue_type: miq_queue" do
        before { stub_settings_merge(:prototype => {:queue_type => 'miq_queue'}) }

        it "Adds event to MiqQueue" do
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
    let(:ems) { FactoryGirl.create(:ext_management_system) }
    context "with a VM" do
      let(:vm) { FactoryGirl.create(:vm, :uid_ems => '3ace5197-3d6a-4cb3-aeb2-e8348e428775', :ems_ref => 'vm-123') }
      let(:event) do
        {
          :ems_id     => ems.id,
          :event_type => 'VmDestroyedEvent',
          :vm_ems_ref => vm.ems_ref,
          :vm_uid_ems => vm.uid_ems,
        }
      end

      context "with a connected VM" do
        before { vm.update_attributes(:ems_id => ems.id) }

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
    let(:provider_event) { 'SomeSpecialProviderEvent' }

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
      expect(described_class.event_groups[:addition][:critical]).not_to include(provider_event)
    end

    it 'returns the provider event if configured' do
      stub_settings_merge(
        :ems => {
          :some_provider => {
            :event_handling => {
              :event_groups => {
                :addition => {
                  :critical => [provider_event]
                }
              }
            }
          }
        }
      )

      expect(described_class.event_groups[:addition][:critical]).to include('CloneTaskEvent')
      expect(described_class.event_groups[:addition][:critical]).to include(provider_event)
    end

    it 'returns the group, level and group name of an unknown event' do
      group, level = described_class.group_and_level(provider_event)
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
  end
end
