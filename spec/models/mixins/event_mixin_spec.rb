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

  context "event_where_clause" do
    let(:ems_id)       { 1234 }
    let(:object_name)  { "object_name" }
    let(:project_name) { "container_project_name" }
    let(:known_missing_event_mixin_classes) { [MiqServer, Storage, ResourcePool, ContainerImage] }

    MiqEvent::SUPPORTED_POLICY_AND_ALERT_CLASSES.each do |klass|
      it "#{klass} includes EventMixin and is correct" do
        pending("Missing EventMixin means timeline support is likely broken") if known_missing_event_mixin_classes.include?(klass)
        expect(klass).to include(EventMixin)

        object = FactoryBot.create(klass.name.tableize.singularize.to_sym)
        expected_event_where_clause_for_ems_events = {
          EmsCluster          => ["ems_cluster_id = ?", object.id],
          ExtManagementSystem => ["event_streams.ems_id = ?", object.id],
          ContainerGroup      => ["container_namespace = ? AND container_group_name = ? AND event_streams.ems_id = ?", project_name, object_name, ems_id],
          ContainerNode       => ["container_node_name = ? AND event_streams.ems_id = ?", object_name, ems_id],
          ContainerProject    => ["container_namespace = ? AND event_streams.ems_id = ?", object_name, ems_id],
          ContainerReplicator => ["container_namespace = ? AND container_replicator_name = ? AND event_streams.ems_id = ?", project_name, object_name, ems_id],
          Host                => ["host_id = ? OR dest_host_id = ?", object.id, object.id],
          PhysicalServer      => ["event_streams.physical_server_id = ?", object.id],
          VmOrTemplate        => ["vm_or_template_id = ? OR dest_vm_or_template_id = ? ", object.id, object.id]
        }

        expected_event_where_clause_for_policy_events = {
          EmsCluster          => ["ems_cluster_id = ?", object.id],
          ExtManagementSystem => ["event_streams.ems_id = ?", object.id],
          ContainerGroup      => ["event_streams.ems_id = ?", ems_id],
          ContainerNode       => ["event_streams.ems_id = ?", ems_id],
          ContainerProject    => ["event_streams.ems_id = ?", ems_id],
          ContainerReplicator => ["event_streams.ems_id = ?", ems_id],
          Host                => ["host_id = ?", object.id],
          PhysicalServer      => ["event_streams.physical_server_id = ?", object.id],
          VmOrTemplate        => ["target_id = ? and target_class = ? ", object.id, "VmOrTemplate"]
        }

        allow(object).to receive(:ems_id).and_return(ems_id)
        allow(object).to receive(:name).and_return(object_name)
        allow(object).to receive(:container_project).and_return(double(:name => project_name))
        expect(object.event_where_clause(:ems_events)).to eq(expected_event_where_clause_for_ems_events[klass])
        expect(object.event_where_clause(:policy_events)).to eq(expected_event_where_clause_for_policy_events[klass])
      end
    end
  end
end
