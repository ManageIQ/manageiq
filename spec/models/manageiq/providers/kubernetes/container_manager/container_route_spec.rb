require "spec_helper"

describe ContainerRoute do
  it "has distinct nodes" do
    node = FactoryGirl.create(:container_node, :name => "n")
    route = FactoryGirl.create(
    :container_route,
    :name => "rt",
    :container_service => FactoryGirl.create(
    :container_service,
    :name => "s",
    :container_groups => [FactoryGirl.create(:container_group, :name => "g1", :container_node => node),
                          FactoryGirl.create(:container_group, :name => "g2", :container_node => node)]
    )
    )
    route.container_nodes.count.should == 1
  end
end
