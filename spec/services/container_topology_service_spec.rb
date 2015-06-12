require "spec_helper"

describe ContainerTopologyService do
  let(:container_topology_service) { described_class.new(nil) }

  describe "#build_kinds" do
    it "creates the expected number of entity types" do
      container_topology_service.build_kinds.size.should eql 6
    end

    it "kinds contains an expected key" do
      container_topology_service.build_kinds.key?(:Pod).should be_true
    end
  end

  describe "#build_link" do
    it "creates link between source to target" do
      container_topology_service.build_link("95e49048-3e00-11e5-a0d2-18037327aaeb",
                                            "96c35f65-3e00-11e5-a0d2-18037327aaeb").size.should eql 2
      container_topology_service.build_link("95e49048-3e00-11e5-a0d2-18037327aaeb",
                                            "96c35f65-3e00-11e5-a0d2-18037327aaeb").key?(:source).should be_true
      container_topology_service.build_link("95e49048-3e00-11e5-a0d2-18037327aaeb",
                                            "96c35f65-3e00-11e5-a0d2-18037327aaeb").key?(:target).should be_true
      container_topology_service.build_link("95e49048-3e00-11e5-a0d2-18037327aaeb",
                                            "96c35f65-3e00-11e5-a0d2-18037327aaeb")[:source].should eq "95e49048-3e00-11e5-a0d2-18037327aaeb"
      container_topology_service.build_link("95e49048-3e00-11e5-a0d2-18037327aaeb",
                                            "96c35f65-3e00-11e5-a0d2-18037327aaeb")[:target].should eq "96c35f65-3e00-11e5-a0d2-18037327aaeb"
    end
  end

  describe "#build_topology" do
    it "topology contains expected number of keys" do
      container_topology_service.build_topology.size.should eql 3
    end

    it "topology contains expected keys" do
      container_topology_service.build_topology.key?(:items).should be_true
      container_topology_service.build_topology.key?(:relations).should be_true
      container_topology_service.build_topology.key?(:kinds).should be_true
    end

    it "topology contains the expected structure and content" do
      ems = FactoryGirl.create(:ems_kubernetes)
      container_node = ContainerNode.create(:ext_management_system => ems, :name => "127.0.0.1", :ems_ref => "905c90ba-3e00-11e5-a0d2-18037327aaeb")
      container_group = ContainerGroup.create(:ext_management_system => ems, :container_node => container_node, :name => "myPod", :ems_ref => "96c35ccd-3e00-11e5-a0d2-18037327aaeb")
      container_service = ContainerService.create(:ext_management_system => ems, :container_groups => [container_group], :ems_ref => "95e49048-3e00-11e5-a0d2-18037327aaeb",
                                              :name => "service1")

      container_topology_service.stub(:entities).and_return([[container_node], [container_service]])
      container_topology_service.build_topology[:items].size.should eql 3
      container_topology_service.build_topology[:relations].size.should eql 2

      container_topology_service.build_topology[:items].key? "905c90ba-3e00-11e5-a0d2-18037327aaeb"
      container_topology_service.build_topology[:items]["905c90ba-3e00-11e5-a0d2-18037327aaeb"].should eql({:metadata => {:id => "905c90ba-3e00-11e5-a0d2-18037327aaeb", :name => "127.0.0.1"}, :kind => "Node"})
    end
  end

  describe "#entities" do
    it "returns correct number of entity types" do
      container_topology_service.entities.size.should eql 2
    end
  end
end
