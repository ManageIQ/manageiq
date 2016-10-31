describe EmsEvent do
  let(:data_dir) { Rails.root.join("spec/models/manageiq/providers/vmware/infra_manager/event_data") }

  context ".add_vc" do
    before(:each) do
      @zone = FactoryGirl.create(:small_environment)
      @ems = @zone.ext_management_systems.first
      @host = @ems.hosts.first
      @vm1, @vm2 = @host.vms.sort_by(&:id)
    end

    it "with a GeneralUserEvent" do
      raw_event = YAML.load_file(File.join(data_dir, 'general_user_event.yml'))
      mock_raw_event_vm(raw_event)
      mock_raw_event_host(raw_event)

      EmsEvent.add_vc(@ems.id, raw_event)

      expect(EmsEvent.count).to eq(1)
      event = EmsEvent.first

      expect(event).to have_attributes(
        :event_type        => "GeneralUserEvent",
        :chain_id          => 5361104,
        :is_task           => false,
        :source            => "VC",
        :message           => "User logged event: EVM SmartState Analysis completed for VM [tch-UBUNTU-904-LTS-DESKTOP]",
        :timestamp         => Time.parse("2010-08-24T01:08:10.396636Z"),
        :username          => "MANAGEIQ\\thennessy",

        :ems_id            => @ems.id,
        :vm_or_template_id => @vm1.id,
        :vm_name           => @vm1.name,
        :vm_location       => @vm1.location,
        :host_id           => @host.id,
        :host_name         => @host.hostname,
      )
    end

    context "with an EventEx event" do
      it "with an eventTypeId" do
        raw_event = YAML.load_file(File.join(data_dir, 'event_ex.yml'))
        mock_raw_event_host(raw_event)

        EmsEvent.add_vc(@ems.id, raw_event)

        expect(EmsEvent.count).to eq(1)
        event = EmsEvent.first

        assert_result_fields(event)
        expect(event).to have_attributes(
          :event_type => "vprob.vmfs.resource.corruptondisk",
          :message    => "event.vprob.vmfs.resource.corruptondisk.fullFormat (vprob.vmfs.resource.corruptondisk)",
        )
      end

      it "without an eventTypeId" do
        raw_event = YAML.load_file(File.join(data_dir, 'event_ex_without_eventtypeid.yml'))
        mock_raw_event_host(raw_event)

        EmsEvent.add_vc(@ems.id, raw_event)

        expect(EmsEvent.count).to eq(1)
        event = EmsEvent.first

        assert_result_fields(event)
        expect(event).to have_attributes(
          :event_type => "EventEx",
          :message    => "",
        )
      end

      def assert_result_fields(event)
        expect(event).to have_attributes(
          :chain_id          => 297179,
          :is_task           => false,
          :source            => "VC",
          :timestamp         => Time.parse("2010-11-12T17:15:42.661128Z"),
          :username          => nil,

          :ems_id            => @ems.id,
          :vm_or_template_id => nil,
          :vm_name           => nil,
          :vm_location       => nil,
          :host_id           => @host.id,
          :host_name         => @host.hostname,
        )
      end
    end

    def mock_raw_event_host(raw_event)
      raw_event["host"]["host"] = @host.ems_ref_obj
      raw_event["host"]["name"] = @host.hostname
    end

    def mock_raw_event_vm(raw_event)
      raw_event["vm"]["vm"]     = @vm1.ems_ref_obj
      raw_event["vm"]["name"]   = @vm1.name
      raw_event["vm"]["path"]   = @vm1.location
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

    context ".purge_date" do
      it "using '3.month' syntax" do
        stub_settings(:ems_events => {:history => {:keep_ems_events => "3.months"}})
        # Exposes 3.months.seconds.ago.utc != 3.months.ago.utc
        expect(described_class.purge_date).to be_within(2.days).of(3.months.ago.utc)
      end

      it "defaults to 6 months" do
        stub_settings(:ems_events => {:history => {:keep_ems_events => nil}})
        expect(described_class.purge_date).to be_within(1.day).of(6.months.ago.utc)
      end
    end

    context "#purge_queue" do
      let(:purge_time) { (Time.now + 10).round }

      before(:each) do
        EvmSpecHelper.create_guid_miq_server_zone
        described_class.purge_queue(purge_time)
      end

      it "submits to the queue" do
        q = MiqQueue.all
        expect(q.length).to eq(1)
        expect(q.first).to have_attributes(
          :class_name  => described_class.name,
          :method_name => "purge",
          :args        => [purge_time]
        )
      end
    end

    context ".purge" do
      let(:purge_date) { 2.weeks.ago }

      before do
        @old_event        = FactoryGirl.create(:ems_event, :timestamp => purge_date - 1.day)
        @purge_date_event = FactoryGirl.create(:ems_event, :timestamp => purge_date)
        @new_event        = FactoryGirl.create(:ems_event, :timestamp => purge_date + 1.day)
      end

      def assert_unpurged_ids(unpurged_ids)
        expect(described_class.order(:id).pluck(:id)).to eq(Array(unpurged_ids).sort)
      end

      it "purge_date and older" do
        described_class.purge(purge_date)
        assert_unpurged_ids(@new_event.id)
      end

      it "with a window" do
        described_class.purge(purge_date, 1)
        assert_unpurged_ids(@new_event.id)
      end

      it "with a limit" do
        described_class.purge(purge_date, nil, 1)
        assert_unpurged_ids([@purge_date_event.id, @new_event.id])
      end

      it "with window > limit" do
        described_class.purge(purge_date, 2, 1)
        assert_unpurged_ids([@purge_date_event.id, @new_event.id])
      end

      it "with limit > window" do
        described_class.purge(purge_date, 1, 2)
        assert_unpurged_ids(@new_event.id)
      end
    end
  end
end
