require "spec_helper"

describe ContainerProject do
  it "has distinct nodes" do
    node = FactoryGirl.create(:container_node, :name => "n")
    FactoryGirl.create(
    :container_project,
    :container_groups => [FactoryGirl.create(:container_group, :name => "g1", :container_node => node),
                          FactoryGirl.create(:container_group, :name => "g2", :container_node => node)]
    ).container_nodes.count.should == 1
  end
end
