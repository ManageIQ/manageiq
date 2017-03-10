describe ManagerRefresh::TargetCollection do
  before(:each) do
    @zone      = FactoryGirl.create(:zone)
    @ems       = FactoryGirl.create(:ems_cloud, :zone => @zone)
    @ems_event = FactoryGirl.create(:ems_event)

    @vm_1 = FactoryGirl.create(
      :vm_cloud,
      :ext_management_system => @ems,
      :ems_ref               => "vm_1"
    )

    @vm_2 = FactoryGirl.create(
      :vm_cloud,
      :ext_management_system => @ems,
      :ems_ref               => "vm_2"
    )
  end

  context ".add_target" do
    it "intializes correct ManagerRefresh::Target object" do
      target_collection = ManagerRefresh::TargetCollection.new(:manager => @ems)

      target_collection.add_target(
        :association => :vms,
        :manager_ref => {:ems_ref => @vm_1.ems_ref},
        :options     => {:opt1 => "opt1", :opt2 => "opt2"}
      )

      expect(target_collection.targets.first).to(
        have_attributes(
          :manager     => @ems,
          :manager_id  => @ems.id,
          :event_id    => nil,
          :association => :vms,
          :manager_ref => {:ems_ref => @vm_1.ems_ref},
          :options     => {:opt1 => "opt1", :opt2 => "opt2"}
        )
      )
    end

    it "intializes correct ManagerRefresh::Target object with manager_id" do
      target_collection = ManagerRefresh::TargetCollection.new(:manager_id => @ems.id, :event => @ems_event)

      target_collection.add_target(
        :association => :vms,
        :manager_ref => {:ems_ref => @vm_1.ems_ref},
        :options     => {:opt1 => "opt1", :opt2 => "opt2"}
      )

      expect(target_collection.targets.first).to(
        have_attributes(
          :manager     => @ems,
          :manager_id  => @ems.id,
          :event_id    => @ems_event.id,
          :association => :vms,
          :manager_ref => {:ems_ref => @vm_1.ems_ref},
          :options     => {:opt1 => "opt1", :opt2 => "opt2"}
        )
      )
    end

    it "intializes correct ManagerRefresh::Target object with event" do
      target_collection = ManagerRefresh::TargetCollection.new(:manager => @ems, :event => @ems_event)

      target_collection.add_target(
        :association => :vms,
        :manager_ref => {:ems_ref => @vm_1.ems_ref},
        :options     => {:opt1 => "opt1", :opt2 => "opt2"}
      )

      expect(target_collection.targets.first).to(
        have_attributes(
          :manager     => @ems,
          :manager_id  => @ems.id,
          :event_id    => @ems_event.id,
          :association => :vms,
          :manager_ref => {:ems_ref => @vm_1.ems_ref},
          :options     => {:opt1 => "opt1", :opt2 => "opt2"}
        )
      )
    end

    it "raises exception when manager not provided in any form" do
      data = {
        :association => :vms,
        :manager_ref => {:ems_ref => @vm_1.ems_ref},
        :options     => {:opt1 => "opt1", :opt2 => "opt2"}
      }

      target_collection = ManagerRefresh::TargetCollection.new

      expect { target_collection.add_target(data) }.to raise_error("Provide either :manager or :manager_id argument")
    end
  end

  context ".name" do
    it "prints names of all targets" do
      target_collection = ManagerRefresh::TargetCollection.new(:manager_id => @ems.id, :event => @ems_event)

      target_collection.add_target(
        :association => :vms,
        :manager_ref => {:ems_ref => @vm_1.ems_ref},
        :options     => {:opt1 => "opt1", :opt2 => "opt2"}
      )

      target_collection.add_target(
        :association => :vms,
        :manager_ref => {:ems_ref => @vm_2.ems_ref},
        :options     => {:opt1 => "opt1", :opt2 => "opt2"}
      )

      expect(target_collection.name).to eq "Collection of targets with name: [{:ems_ref=>\"vm_1\"}, {:ems_ref=>\"vm_2\"}]"
    end
  end

  context ".id" do
    it "prints ids of all targets" do
      target_collection = ManagerRefresh::TargetCollection.new(:manager_id => @ems.id, :event => @ems_event)

      target_collection.add_target(
        :association => :vms,
        :manager_ref => {:ems_ref => @vm_1.ems_ref},
        :options     => {:opt1 => "opt1", :opt2 => "opt2"}
      )

      target_collection.add_target(
        :association => :vms,
        :manager_ref => {:ems_ref => @vm_2.ems_ref},
        :options     => {:opt1 => "opt1", :opt2 => "opt2"}
      )

      expect(target_collection.id).to include ":ems_ref=>\"vm_1\""
      expect(target_collection.id).to include ":ems_ref=>\"vm_2\""
    end
  end

  context ".manager_refs_by_association" do
    it "returns all manager refs grouped by association" do
      target_collection = ManagerRefresh::TargetCollection.new(:manager_id => @ems.id, :event => @ems_event)

      target_collection.add_target(
        :association => :vms,
        :manager_ref => {:ems_ref => @vm_1.ems_ref},
        :options     => {:opt1 => "opt1", :opt2 => "opt2"}
      )

      target_collection.add_target(
        :association => :vms,
        :manager_ref => {:ems_ref => @vm_2.ems_ref},
        :options     => {:opt1 => "opt1", :opt2 => "opt2"}
      )

      target_collection.add_target(
        :association => :network_ports,
        :manager_ref => {:ems_ref => "network_port_1"},
        :options     => {:opt1 => "opt1", :opt2 => "opt2"}
      )

      expect(target_collection.manager_refs_by_association[:vms][:ems_ref].to_a).to(
        match_array(["vm_1", "vm_2"])
      )
      expect(target_collection.manager_refs_by_association[:network_ports][:ems_ref].to_a).to(
        match_array(["network_port_1"])
      )
    end

    it "handles duplicates" do
      target_collection = ManagerRefresh::TargetCollection.new(:manager_id => @ems.id, :event => @ems_event)

      target_collection.add_target(
        :association => :vms,
        :manager_ref => {:ems_ref => @vm_1.ems_ref},
        :options     => {:opt1 => "opt1", :opt2 => "opt2"}
      )

      # Adding a duplicate Vm
      target_collection.add_target(
        :association => :vms,
        :manager_ref => {:ems_ref => @vm_1.ems_ref},
        :options     => {:opt1 => "opt1", :opt2 => "opt2"}
      )

      # Checking the duplicate is there
      expect(target_collection.targets.map(&:dump)).to(
        match_array(
          [
            {
              :manager_id  => @ems.id,
              :event_id    => @ems_event.id,
              :association => :vms,
              :manager_ref => {:ems_ref => @vm_1.ems_ref},
              :options     => {:opt1 => "opt1", :opt2 => "opt2"}
            }, {
              :manager_id  => @ems.id,
              :event_id    => @ems_event.id,
              :association => :vms,
              :manager_ref => {:ems_ref => @vm_1.ems_ref},
              :options     => {:opt1 => "opt1", :opt2 => "opt2"}
            }
          ]
        )
      )

      # Checking the manager_refs_by_association handle duplicate
      expect(target_collection.manager_refs_by_association[:vms][:ems_ref].to_a).to(
        match_array(["vm_1"])
      )
    end

    it "caches the result until manager_refs_by_association_reset is called" do
      target_collection = ManagerRefresh::TargetCollection.new(:manager_id => @ems.id, :event => @ems_event)

      target_collection.add_target(
        :association => :vms,
        :manager_ref => {:ems_ref => @vm_1.ems_ref},
        :options     => {:opt1 => "opt1", :opt2 => "opt2"}
      )

      target_collection.add_target(
        :association => :vms,
        :manager_ref => {:ems_ref => @vm_2.ems_ref},
        :options     => {:opt1 => "opt1", :opt2 => "opt2"}
      )

      target_collection.add_target(
        :association => :network_ports,
        :manager_ref => {:ems_ref => "network_port_1"},
        :options     => {:opt1 => "opt1", :opt2 => "opt2"}
      )

      expect(target_collection.manager_refs_by_association[:vms][:ems_ref].to_a).to(
        match_array(["vm_1", "vm_2"])
      )
      expect(target_collection.manager_refs_by_association[:network_ports][:ems_ref].to_a).to(
        match_array(["network_port_1"])
      )

      # Adding new target
      target_collection.add_target(
        :association => :network_ports,
        :manager_ref => {:ems_ref => "network_port_2"},
        :options     => {:opt1 => "opt1", :opt2 => "opt2"}
      )

      # check that manager_refs_by_association returns cached result
      expect(target_collection.manager_refs_by_association[:network_ports][:ems_ref].to_a).to(
        match_array(["network_port_1"])
      )

      # Clear the cache and check new target is present
      target_collection.manager_refs_by_association_reset
      expect(target_collection.manager_refs_by_association[:network_ports][:ems_ref].to_a).to(
        match_array(["network_port_1", "network_port_2"])
      )
    end
  end
end
