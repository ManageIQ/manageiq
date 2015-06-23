require "spec_helper"
require Rails.root.join("db/migrate/20150522161336_add_container_entities_type")

describe AddContainerEntitiesType do
  let(:container_node_stub)  { migration_stub(:ContainerNode) }
  let(:container_stub)       { migration_stub(:Container) }
  let(:container_group_stub) { migration_stub(:ContainerGroup) }

  migration_context :up do
    it "up" do
      container_node = container_node_stub.create!
      container = container_stub.create!
      container_group = container_group_stub.create!

      migrate

      expect(container_node.reload).to have_attributes(:type => "ContainerNodeKubernetes")
      expect(container.reload).to have_attributes(:type => "ContainerKubernetes")
      expect(container_group.reload).to have_attributes(:type => "ContainerGroupKubernetes")
    end
  end

  migration_context :down do
    it "down" do
      container_node = container_node_stub.create!(:type => "ContainerNodeKubernetes")
      container = container_stub.create!(:type => "ContainerKubernetes")
      container_group = container_group_stub.create!(:type => "ContainerGroupKubernetes")

      migrate

      ContainerNode.find(container_node.id).should_not respond_to(:type)
      Container.find(container.id).should_not respond_to(:type)
      ContainerGroup.find(container_group.id).should_not respond_to(:type)
    end
  end
end
