describe EmsEvent do
  context "model" do
    let(:ems1) { FactoryGirl.create(:ems_kubernetes) }
    let(:ems2) { FactoryGirl.create(:ems_hawkular_datawarehouse) }

    it "Find ems events and generated events for ext management systems" do
      generated_event = FactoryGirl.create(:ems_event, :ext_management_system => ems1, :generating_ems => ems2)
      expect(ems1.ems_events).to match_array([generated_event])
      expect(ems2.generated_events).to match_array([generated_event])
    end
  end

  context "container events" do
    let(:ems_ref) { "test_ems_ref" }

    before :each do
      @ems = FactoryGirl.create(:ems_kubernetes)
      @container_project = FactoryGirl.create(:container_project, :ext_management_system => @ems)
      @event_hash = {
        :ems_ref    => ems_ref,
        :ems_id     => @ems.id,
        :event_type => "STUFF_HAPPENED"
      }
    end

    context "on node" do
      before :each do
        @container_node = FactoryGirl.create(:container_node,
                                             :ext_management_system => @ems,
                                             :name                  => "Test Node",
                                             :ems_ref               => ems_ref)
      end

      it "process_container_entities_in_event! links node id to event" do
        EmsEvent.process_container_entities_in_event!(@event_hash)
        expect(@event_hash[:container_node_id]).to eq @container_node.id
      end

      it "constructed event has .container_node" do
        event = EmsEvent.add(@ems.id, @event_hash)
        expect(event.container_node).to eq @container_node
      end
    end

    context "on pod" do
      before :each do
        @container_group = FactoryGirl.create(:container_group,
                                              :ext_management_system => @ems,
                                              :container_project     => @container_project,
                                              :name                  => "Test Group",
                                              :ems_ref               => ems_ref)
      end

      it "process_container_entities_in_event! links pod id to event" do
        EmsEvent.process_container_entities_in_event!(@event_hash)
        expect(@event_hash[:container_group_id]).to eq @container_group.id
      end

      it "constructed event has .container_group" do
        event = EmsEvent.add(@ems.id, @event_hash)
        expect(event.container_group).to eq @container_group
      end
    end

    context "on replicator" do
      before :each do
        @container_replicator = FactoryGirl.create(:container_replicator,
                                                   :ext_management_system => @ems,
                                                   :container_project     => @container_project,
                                                   :name                  => "Test Replicator",
                                                   :ems_ref               => ems_ref)
      end

      it "process_container_entities_in_event! links replicator id to event" do
        EmsEvent.process_container_entities_in_event!(@event_hash)
        expect(@event_hash[:container_replicator_id]).to eq @container_replicator.id
      end

      it "constructed event has .container_replicator" do
        event = EmsEvent.add(@ems.id, @event_hash)
        expect(event.container_replicator).to eq @container_replicator
      end
    end
  end

  context ".process_middleware_entities_in_event!" do
    let(:middleware_ref) { "hawkular-test-path" }
    let(:ems) { FactoryGirl.create(:ems_hawkular) }
    let(:middleware_server) do
      FactoryGirl.create(:middleware_server,
                         :ems_ref               => middleware_ref,
                         :name                  => 'test-server',
                         :ext_management_system => ems)
    end

    let(:event_hash) { {:middleware_type => MiddlewareServer.name, :ems_id => ems.id} }

    before :each do
      middleware_server
    end

    context "process server_in events" do
      it "should link server id to event" do
        event_hash[:middleware_ref] = middleware_ref
        EmsEvent.process_middleware_entities_in_event!(event_hash)
        expect(event_hash[:middleware_server_id]).to eq middleware_server.id
        expect(event_hash[:middleware_server_name]).to eq middleware_server.name
      end
    end

    context "process unknown_server_in events" do
      it "should not link server id to event" do
        event_hash[:middleware_ref] = 'unknown_id'
        EmsEvent.process_middleware_entities_in_event!(event_hash)
        expect(event_hash[:middleware_server_id]).to be_nil
        expect(event_hash[:middleware_server_name]).to be_nil
      end
    end
  end

  context "with availability zones" do
    before :each do
      @zone = FactoryGirl.create(:small_environment)
      @ems  = @zone.ext_management_systems.first
      @vm = FactoryGirl.create(:vm_openstack, :ems_ref => "vm1")
      @availability_zone = FactoryGirl.create(:availability_zone_openstack, :ems_ref => "az1")
    end

    context ".process_availability_zone_in_event!" do
      before :each do
        @event_hash = {
          :vm_or_template_id => @vm.id
        }
      end

      context "when the event has an availability zone" do
        before :each do
          @event_hash[:availability_zone_ems_ref] = @availability_zone.ems_ref
        end

        it "should use the availability zone from the event" do
          EmsEvent.process_availability_zone_in_event!(@event_hash)
          expect(@event_hash[:availability_zone_id]).to eq @availability_zone.id
        end
      end

      context "when the event has no availability zone" do
        context "and the VM has an availability zone" do
          before :each do
            @vm.availability_zone_id = @availability_zone.id
            @vm.save
          end

          it "should use the VM's availability zone" do
            EmsEvent.process_availability_zone_in_event!(@event_hash)
            expect(@event_hash[:availability_zone_id]).to eq @availability_zone.id
          end
        end

        context "and the VM does not have an availability zone" do
          it "should not put an availability zone in the event hash" do
            EmsEvent.process_availability_zone_in_event!(@event_hash)
            expect(@event_hash[:availability_zone_id]).to be_nil
          end
        end
      end
    end

    context ".add" do
      before :each do
        @event_hash = {
          :event_type => "event_with_availability_zone",
          :vm_ems_ref => @vm.ems_ref,
          :timestamp  => Time.now,
          :ems_id     => @ems.id
        }
      end

      context "when the event does not have an availability zone" do
        it "should create an event record with the VMs availability zone" do
          @vm.availability_zone_id = @availability_zone.id
          @vm.save

          new_event = EmsEvent.add(@vm.ems_id, @event_hash)
          expect(new_event.availability_zone_id).to eq @availability_zone.id
        end
      end

      context "when the event does contain an availability zone" do
        it "should use the availability zone from the event" do
          @event_hash[:availability_zone_ems_ref] = @availability_zone.ems_ref
          @vm.availability_zone_id = nil
          @vm.save

          new_event = EmsEvent.add(@vm.ems_id, @event_hash)
          expect(new_event.availability_zone_id).to eq @availability_zone.id
        end
      end
    end
  end

  context '.event_groups' do
    let(:provider_event) { 'SomeSpecialProviderEvent' }

    it 'returns a list of groups' do
      event_group_names = [
        :addition, :application, :configuration, :console, :deletion, :general, :import_export, :migration, :network,
        :power, :snapshot, :status, :storage
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
                  :name     => 'This name will not make it into event_groups',
                  :critical => [provider_event]
                }
              }
            }
          }
        }
      )
      allow(Vmdb::Plugins.instance).to receive(:registered_provider_plugin_names).and_return([:some_provider])

      expect(described_class.event_groups[:addition]).to include(:name => 'Creation/Addition')
      expect(described_class.event_groups[:addition][:critical]).to include('CloneTaskEvent')
      expect(described_class.event_groups[:addition][:critical]).to include(provider_event)
    end
  end
end
