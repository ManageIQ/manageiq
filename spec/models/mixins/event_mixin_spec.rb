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
    let(:project_name) { "container_project_name" }
    let(:known_missing_event_mixin_classes) { [MiqServer, Storage, ResourcePool, ContainerImage] }

    # TODO: The classes: Storage, ContainerImage, ResourcePool:
    #  * Do NOT have _id columns in event_streams
    #  * Do NOT include EventMixin
    #  * Are included in MiqEvent::SUPPORTED_POLICY_AND_ALERT_CLASSES
    #
    # TODO: The classes:  AvailabilityZone, Container, PhysicalChassis, PhysicalSwitch
    #   * Do have id columns in event_streams
    #   * Do include EventMixin
    #   * Are NOT included in MiqEvent::SUPPORTED_POLICY_AND_ALERT_CLASSES
    context "AvailabilityZone" do
      let(:object)       { FactoryBot.create(:availability_zone) }
      let(:other_object) { FactoryBot.create(:availability_zone) }

      it "ems_events" do
        expected1 = FactoryBot.create(:ems_event, :availability_zone_id => object.id)
        FactoryBot.create(:ems_event, :availability_zone_id => other_object.id)
        expect(object.event_where_clause(:ems_events)).to match_array([expected1])
      end

      it "miq_events" do
        expected1 = FactoryBot.create(:miq_event, :availability_zone_id => object.id)
        FactoryBot.create(:miq_event, :availability_zone_id => other_object.id)
        expect(object.event_where_clause(:miq_events)).to match_array([expected1])
      end
    end

    context "Container" do
      let(:object)       { FactoryBot.create(:container, :ems_id => ems_id) }
      let(:other_object) { FactoryBot.create(:container, :ems_id => ems_id) }

      it "ems_events" do
        expected1 = FactoryBot.create(:ems_event, :ems_id => ems_id, :container_name => object.name, :container_namespace => project_name)
        FactoryBot.create(:ems_event, :ems_id => other_object.id)
        FactoryBot.create(:ems_event, :ems_id => ems_id, :container_name => object.name)
        FactoryBot.create(:ems_event, :ems_id => ems_id, :container_namespace => project_name)
        allow(object).to receive(:container_project).and_return(double(:name => project_name))
        allow(object).to receive(:ext_management_system).and_return(double(:id => ems_id))
        expect(object.event_where_clause(:ems_events)).to match_array([expected1])
      end

      it "miq_events" do
        expected1 = FactoryBot.create(:miq_event, :ems_id => ems_id)
        FactoryBot.create(:miq_event, :ems_id => other_object.id)
        allow(object).to receive(:ext_management_system).and_return(double(:id => ems_id))
        expect(object.event_where_clause(:miq_events)).to match_array([expected1])
      end
    end

    context "ContainerGroup" do
      let(:object)       { FactoryBot.create(:container_group, :ems_id => ems_id) }
      let(:other_object) { FactoryBot.create(:container_group, :ems_id => ems_id) }

      it "ems_events" do
        expected1 = FactoryBot.create(:ems_event, :ems_id => ems_id, :container_group_name => object.name, :container_namespace => project_name)
        FactoryBot.create(:ems_event, :ems_id => other_object.id)
        FactoryBot.create(:ems_event, :ems_id => ems_id, :container_group_name => object.name)
        FactoryBot.create(:ems_event, :ems_id => ems_id, :container_namespace => project_name)
        allow(object).to receive(:container_project).and_return(double(:name => project_name))
        expect(object.event_where_clause(:ems_events)).to match_array([expected1])
      end

      it "miq_events" do
        expected1 = FactoryBot.create(:miq_event, :ems_id => ems_id)
        FactoryBot.create(:miq_event, :ems_id => other_object.id)
        expect(object.event_where_clause(:miq_events)).to match_array([expected1])
      end
    end

    context "ContainerNode" do
      let(:object)       { FactoryBot.create(:container_node, :ems_id => ems_id) }
      let(:other_object) { FactoryBot.create(:container_node, :ems_id => ems_id) }

      it "ems_events" do
        expected1 = FactoryBot.create(:ems_event, :ems_id => ems_id, :container_node_name => object.name)
        FactoryBot.create(:ems_event, :ems_id => ems_id, :container_node_name => other_object.name)
        FactoryBot.create(:ems_event, :ems_id => other_object.id, :container_node_name => object.name)
        expect(object.event_where_clause(:ems_events)).to match_array([expected1])
      end

      it "miq_events" do
        expected1 = FactoryBot.create(:miq_event, :ems_id => ems_id)
        FactoryBot.create(:miq_event, :ems_id => other_object.id)
        expect(object.event_where_clause(:miq_events)).to match_array([expected1])
      end
    end

    context "ContainerProject" do
      let(:object)       { FactoryBot.create(:container_project, :ems_id => ems_id) }
      let(:other_object) { FactoryBot.create(:container_project, :ems_id => ems_id) }
      it "ems_events" do
        expected1 = FactoryBot.create(:ems_event, :ems_id => ems_id, :container_namespace => object.name)
        FactoryBot.create(:ems_event, :ems_id => ems_id, :container_namespace => other_object.name)
        FactoryBot.create(:ems_event, :ems_id => other_object.id, :container_namespace => object.name)
        expect(object.event_where_clause(:ems_events)).to match_array([expected1])
      end

      it "miq_events" do
        expected1 = FactoryBot.create(:miq_event, :ems_id => ems_id)
        FactoryBot.create(:miq_event, :ems_id => other_object.id)
        expect(object.event_where_clause(:miq_events)).to match_array([expected1])
      end
    end

    context "ContainerReplicator" do
      let(:object)       { FactoryBot.create(:container_replicator, :ems_id => ems_id) }
      let(:other_object) { FactoryBot.create(:container_replicator, :ems_id => ems_id) }

      it "ems_events" do
        expected1 = FactoryBot.create(:ems_event, :ems_id => ems_id, :container_replicator_name => object.name, :container_namespace => project_name)
        FactoryBot.create(:ems_event, :ems_id => other_object.id)
        FactoryBot.create(:ems_event, :ems_id => ems_id, :container_replicator_name => object.name)
        FactoryBot.create(:ems_event, :ems_id => ems_id, :container_namespace => project_name)
        allow(object).to receive(:container_project).and_return(double(:name => project_name))
        expect(object.event_where_clause(:ems_events)).to match_array([expected1])
      end

      it "miq_events" do
        expected1 = FactoryBot.create(:miq_event, :ems_id => ems_id)
        FactoryBot.create(:miq_event, :ems_id => other_object.id)
        expect(object.event_where_clause(:miq_events)).to match_array([expected1])
      end
    end

    context "EmsCluster" do
      let(:object)       { FactoryBot.create(:ems_cluster) }
      let(:other_object) { FactoryBot.create(:ems_cluster) }

      it "ems_events" do
        expected1 = FactoryBot.create(:ems_event, :ems_cluster_id => object.id)
        expected2 = FactoryBot.create(:ems_event, :host_id => object.id)
        expected3 = FactoryBot.create(:ems_event, :vm_or_template_id => object.id)
        expected4 = FactoryBot.create(:ems_event, :dest_vm_or_template_id => object.id)
        FactoryBot.create(:ems_event, :ems_cluster_id => other_object.id)
        FactoryBot.create(:ems_event, :host_id => other_object.id)
        FactoryBot.create(:ems_event, :vm_or_template_id => other_object.id)
        FactoryBot.create(:ems_event, :dest_vm_or_template_id => other_object.id)

        # Pretend there's hosts and vms for this cluster
        allow(object).to receive(:host_ids).and_return([object.id])
        allow(object).to receive(:vm_or_template_ids).and_return([object.id])
        expect(object.event_where_clause(:ems_events)).to match_array([expected1, expected2, expected3, expected4])
      end

      it "miq_events" do
        expected1 = FactoryBot.create(:miq_event, :ems_cluster_id => object.id)
        FactoryBot.create(:miq_event, :ems_cluster_id => other_object.id)
        expect(object.event_where_clause(:miq_events)).to match_array([expected1])
      end
    end

    context "ExtManagementSystem" do
      let(:object)       { FactoryBot.create(:ext_management_system) }
      let(:other_object) { FactoryBot.create(:ext_management_system) }

      it "ems_events" do
        expected1 = FactoryBot.create(:ems_event, :ems_id => object.id)
        FactoryBot.create(:ems_event, :ems_id => other_object.id)
        expect(object.event_where_clause(:ems_events)).to match_array([expected1])
      end

      it "miq_events" do
        expected1 = FactoryBot.create(:miq_event, :ems_id => object.id)
        FactoryBot.create(:miq_event, :ems_id => other_object.id)
        expect(object.event_where_clause(:miq_events)).to match_array([expected1])
      end
    end

    context "Host" do
      let(:object)       { FactoryBot.create(:host) }
      let(:other_object) { FactoryBot.create(:host) }

      it "ems_events" do
        expected1 = FactoryBot.create(:ems_event, :host_id => object.id)
        expected2 = FactoryBot.create(:ems_event, :dest_host_id => object.id)
        FactoryBot.create(:ems_event, :host_id => other_object.id)
        FactoryBot.create(:ems_event, :dest_host_id => other_object.id)
        expect(object.event_where_clause(:ems_events)).to match_array([expected1, expected2])
      end

      it "miq_events" do
        expected1 = FactoryBot.create(:miq_event, :host_id => object.id)
        FactoryBot.create(:miq_event, :host_id => other_object.id)
        expect(object.event_where_clause(:miq_events)).to match_array([expected1])
      end
    end

    context "PhysicalChassis" do
      let(:object)       { FactoryBot.create(:physical_chassis) }
      let(:other_object) { FactoryBot.create(:physical_chassis) }

      it "ems_events" do
        expected1 = FactoryBot.create(:ems_event, :physical_chassis_id => object.id)
        FactoryBot.create(:ems_event, :physical_chassis_id => other_object.id)
        expect(object.event_where_clause(:ems_events)).to match_array([expected1])
      end

      it "miq_events" do
        expected1 = FactoryBot.create(:miq_event, :physical_chassis_id => object.id)
        FactoryBot.create(:miq_event, :physical_chassis_id => other_object.id)
        expect(object.event_where_clause(:miq_events)).to match_array([expected1])
      end
    end

    context "PhysicalServer" do
      let(:object)       { FactoryBot.create(:physical_server) }
      let(:other_object) { FactoryBot.create(:physical_server) }

      it "ems_events" do
        expected1 = FactoryBot.create(:ems_event, :physical_server_id => object.id)
        FactoryBot.create(:ems_event, :physical_server_id => other_object.id)
        expect(object.event_where_clause(:ems_events)).to match_array([expected1])
      end

      it "miq_events" do
        expected1 = FactoryBot.create(:miq_event, :physical_server_id => object.id)
        FactoryBot.create(:miq_event, :physical_server_id => other_object.id)
        expect(object.event_where_clause(:miq_events)).to match_array([expected1])
      end
    end

    context "PhysicalChassis" do
      let(:object)       { FactoryBot.create(:physical_switch) }
      let(:other_object) { FactoryBot.create(:physical_switch) }

      it "ems_events" do
        expected1 = FactoryBot.create(:ems_event, :physical_switch_id => object.id)
        FactoryBot.create(:ems_event, :physical_switch_id => other_object.id)
        expect(object.event_where_clause(:ems_events)).to match_array([expected1])
      end

      it "miq_events" do
        expected1 = FactoryBot.create(:miq_event, :physical_switch_id => object.id)
        FactoryBot.create(:miq_event, :physical_switch_id => other_object.id)
        expect(object.event_where_clause(:miq_events)).to match_array([expected1])
      end
    end

    context "VmOrTemplate" do
      let(:object)       { FactoryBot.create(:vm_or_template) }
      let(:other_object) { FactoryBot.create(:vm_or_template) }

      it "ems_events" do
        expected1 = FactoryBot.create(:ems_event, :vm_or_template_id => object.id)
        expected2 = FactoryBot.create(:ems_event, :dest_vm_or_template_id => object.id)
        FactoryBot.create(:ems_event, :vm_or_template_id => other_object.id)
        FactoryBot.create(:ems_event, :dest_vm_or_template_id => other_object.id)
        expect(object.event_where_clause(:ems_events)).to match_array([expected1, expected2])
      end

      it "miq_events" do
        expected1 = FactoryBot.create(:miq_event, :target_id => object.id, :target_type => object.class.name)
        FactoryBot.create(:miq_event, :target_id => other_object.id, :target_type => other_object.class.name)
        expect(object.event_where_clause(:miq_events)).to match_array([expected1])
      end
    end

    MiqEvent::SUPPORTED_POLICY_AND_ALERT_CLASSES.each do |klass|
      it "#{klass} includes EventMixin and is correct" do
        pending("Missing EventMixin means timeline support is likely broken") if known_missing_event_mixin_classes.include?(klass)
        expect(klass).to include(EventMixin)
      end
    end
  end
end
