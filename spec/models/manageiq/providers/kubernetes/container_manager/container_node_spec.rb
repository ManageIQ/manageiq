require "spec_helper"

describe ContainerNode do
  it "has distinct routes" do
    service = FactoryGirl.create(
    :container_service,
    :name => "s",
    :container_routes => [FactoryGirl.create(:container_route, :name => "rt")]
    )
    FactoryGirl.create(
    :container_node,
    :name => "n",
    :container_groups => [FactoryGirl.create(:container_group, :name => "g1", :container_services => [service]),
                          FactoryGirl.create(:container_group, :name => "g2", :container_services => [service])]
    ).container_routes.count.should == 1
  end
end
