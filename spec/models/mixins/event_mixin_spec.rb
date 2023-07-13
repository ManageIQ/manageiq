RSpec.describe EventMixin do
  context "Included in a test class with events" do
    let(:test_class) do
      Class.new do
        include SupportsFeatureMixin
        include EventMixin

        def event_where_clause(assoc)
          ["#{events_table_name(assoc)}.ems_id = ?", 1]
        end
      end
    end

    before do
      @ts_1 = 5.days.ago
      FactoryBot.create(:ems_event, :ems_id => 1, :timestamp => @ts_1)
      @ts_2 = 4.days.ago
      FactoryBot.create(:ems_event, :ems_id => 1, :timestamp => @ts_2)
      @ts_3 = 3.days.ago
      FactoryBot.create(:ems_event, :ems_id => 1, :timestamp => @ts_3)
    end

    it "#first_event" do
      expect(test_class.new.first_event).to be_within(0.1).of @ts_1
    end

    it "#last_event" do
      expect(test_class.new.last_event).to  be_within(0.1).of @ts_3
    end

    it "#first_and_last_event" do
      events = test_class.new.first_and_last_event
      expect(events.length).to eq(2)
      expect(events[0]).to     be_within(0.1).of @ts_1
      expect(events[1]).to     be_within(0.1).of @ts_3
    end

    it "#has_events?" do
      expect(test_class.new).to have_events
    end
  end

  context "event_stream_filters" do
    # Note
    # 1) BottleneckEvent is not including event mixin, event_where_clause references missing resource_type, resource_id on event streams
    # 2) EmsCluster#event_where_clause does an OR:  ems_cluster_id OR (host_id in ? OR dest_host_id IN ?) OR (vm_or_template in ? OR dest_vm_or_template_id in ?) (for now we just do ems_cluster_id in ems_event_filter)
    # 3) Host#event_where_clause does an OR: host_id OR dest_host_id... right now we only do host_id in ems_event_filter
    # 4) VmOrTemplate#event_where_clause does an OR: vm_or_template_id OR dest_vm_or_template_id, we only do vm_or_template_id in ems_event_filter
    %w[
      AvailabilityZone    availability_zone_id
      EmsCluster          ems_cluster_id
      ExtManagementSystem ems_id
      Host                host_id
      PhysicalChassis     physical_chassis_id
      PhysicalServer      physical_server_id
      PhysicalStorage     physical_storage_id
      PhysicalSwitch      physical_switch_id
      VmOrTemplate        vm_or_template_id
      Vm                  vm_or_template_id
    ].each_slice(2) do |klass, column|
      it "#{klass} uses #{column} and target_id and target_type" do
        obj = FactoryBot.create(klass.tableize.singularize)
        expect(obj.event_stream_filters["EmsEvent"]).to eq(column => obj.id)
        expect(obj.event_stream_filters.dig("MiqEvent", "target_id")).to eq(obj.id)
        expect(obj.event_stream_filters.dig("MiqEvent", "target_type")).to eq(obj.class.base_class.name)
      end

      it "#{klass} behaves like event_where_clause for ems_events" do
        obj = FactoryBot.create(klass.tableize.singularize)
        event = FactoryBot.create(:event_stream, column => obj.id)
        FactoryBot.create(:event_stream)
        expect(EventStream.where(obj.event_stream_filters["EmsEvent"]).to_a).to eq([event])
        expect(EventStream.where(obj.event_where_clause(:ems_events)).to_a).to eq([event])
      end

      # # TODO: some classes don't have this implemented or don't have columns for this
      # # Do we consolidate policy events and miq events?
      # it "behaves like event_where_clause for #{klass} for policy_events" do
      #   obj = FactoryBot.create(klass.tableize.singularize)
      #   event = FactoryBot.create(:event_stream, :target => obj)
      #   FactoryBot.create(:event_stream)
      #   expect(EventStream.where(obj.event_stream_filters["MiqEvent"]).to_a).to eq([event])
      #   pending("policy_events or miq events aren't implemented in all classes and are likely busted")
      #   expect(EventStream.where(obj.event_where_clause(:policy_events)).to_a).to eq([event])
      # end
    end

    context "custom behavior" do
      it "Container uses container_namespace, container_name in ems events" do
        ems     = FactoryBot.create(:ext_management_system)
        project = FactoryBot.create(:container_project)
        obj     = FactoryBot.create(:container, :container_project => project, :ext_management_system => ems)
        event   = FactoryBot.create(:event_stream, :container_namespace => project.name, :ems_id => ems.id, :container_name => obj.name)
        FactoryBot.create(:event_stream, :ems_id => ems.id)

        expect(obj.event_stream_filters["EmsEvent"]).to eq("container_namespace" => project.name, "ems_id" => ems.id, "container_name" => obj.name)
        expect(EventStream.where(obj.event_where_clause(:ems_events)).to_a).to eq([event])
        expect(EventStream.where(obj.event_stream_filters["EmsEvent"]).to_a).to eq([event])
      end

      it "ContainerGroup uses container_namespace, container_group_name, and ems_id in ems events" do
        ems     = FactoryBot.create(:ext_management_system)
        project = FactoryBot.create(:container_project)
        obj     = FactoryBot.create(:container_group, :container_project => project, :ext_management_system => ems)
        event   = FactoryBot.create(:event_stream, :container_namespace => project.name, :ems_id => ems.id, :container_group_name => obj.name)
        FactoryBot.create(:event_stream, :ems_id => ems.id)

        expect(obj.event_stream_filters["EmsEvent"]).to eq("container_namespace" => project.name, "ems_id" => ems.id, "container_group_name" => obj.name)
        expect(EventStream.where(obj.event_where_clause(:ems_events)).to_a).to eq([event])
        expect(EventStream.where(obj.event_stream_filters["EmsEvent"]).to_a).to eq([event])
      end

      it "ContainerNode uses container_node_name and ems_id in ems events" do
        ems   = FactoryBot.create(:ems_container)
        obj   = FactoryBot.create(:container_node, :name => "test", :ext_management_system => ems)
        event = FactoryBot.create(:event_stream, :container_node_name => obj.name, :ems_id => ems.id)
        FactoryBot.create(:event_stream, :ems_id => ems.id)

        expect(obj.event_stream_filters["EmsEvent"]).to eq("container_node_name" => obj.name, "ems_id" => ems.id)
        expect(EventStream.where(obj.event_where_clause(:ems_events)).to_a).to eq([event])
        expect(EventStream.where(obj.event_stream_filters["EmsEvent"]).to_a).to eq([event])
      end

      it "ContainerProject uses container_namespace(name) and ems_id in ems events" do
        ems   = FactoryBot.create(:ems_container)
        obj   = FactoryBot.create(:container_project, :ext_management_system => ems)
        event = FactoryBot.create(:event_stream, :container_namespace => obj.name, :ems_id => ems.id)
        FactoryBot.create(:event_stream, :ems_id => ems.id)

        expect(obj.event_stream_filters["EmsEvent"]).to eq("container_namespace" => obj.name, "ems_id" => ems.id)
        expect(EventStream.where(obj.event_where_clause(:ems_events)).to_a).to eq([event])
        expect(EventStream.where(obj.event_stream_filters["EmsEvent"]).to_a).to eq([event])
      end

      it "ContainerReplicator uses container_namespace, container_replicator_name, and ems_id in ems events" do
        ems      = FactoryBot.create(:ems_container)
        project  = FactoryBot.create(:container_project)
        obj      = FactoryBot.create(:container_replicator, :name => "test", :ext_management_system => ems, :container_project => project)
        event    = FactoryBot.create(:event_stream, :container_namespace => project.name, :ems_id => ems.id, :container_replicator_name => obj.name)
        FactoryBot.create(:event_stream, :ems_id => ems.id)

        expect(obj.event_stream_filters["EmsEvent"]).to eq("container_namespace" => project.name, "container_replicator_name" => obj.name, "ems_id" => ems.id)
        expect(EventStream.where(obj.event_where_clause(:ems_events)).to_a).to eq([event])
        expect(EventStream.where(obj.event_stream_filters["EmsEvent"]).to_a).to eq([event])
      end
    end
  end

  context "Included in a test class with no events" do
    let(:test_class) do
      Class.new do
        include SupportsFeatureMixin
        include EventMixin

        def event_where_clause(assoc)
          ["#{events_table_name(assoc)}.ems_id = ?", nil]
        end
      end
    end

    it "#first_event" do
      expect(test_class.new.first_event).to be_nil
    end

    it "#last_event" do
      expect(test_class.new.last_event).to  be_nil
    end

    it "#first_and_last_event" do
      expect(test_class.new.first_and_last_event).to be_empty
    end

    it "#has_events?" do
      expect(test_class.new).not_to have_events
    end
  end
end
