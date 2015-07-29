require "spec_helper"

describe EmsRefresh::Refreshers::OpenshiftRefresher do
  before(:each) do
    MiqServer.stub(:my_zone).and_return("default")
    @ems = FactoryGirl.create(:ems_openshift, :hostname => "10.35.0.174")
  end

  it "will perform a full refresh on openshift" do
    2.times do
      @ems.reload
      VCR.use_cassette("#{described_class.name.underscore}") do # , :record => :new_episodes) do
        EmsRefresh.refresh(@ems)
      end
      @ems.reload

      assert_ems
      assert_table_counts
      assert_specific_container
      assert_specific_container_group
      assert_specific_container_node
      assert_specific_container_service
      assert_specific_container_project
      assert_specific_container_route
    end
  end

  def assert_table_counts
    ContainerGroup.count.should == 5
    ContainerNode.count.should == 1
    Container.count.should == 5
    ContainerService.count.should == 4
    ContainerPortConfig.count.should == 4
    ContainerDefinition.count.should == 5
    ContainerRoute.count.should == 1
    ContainerProject.count.should == 4
  end

  def assert_ems
    @ems.should have_attributes(
                    :port => "8443",
                    :type => "EmsOpenshift"
                )
  end

  def assert_specific_container
    @container = Container.find_by_name("ruby-helloworld-database")
    @container.should have_attributes(
      :name          => "ruby-helloworld-database",
      :restart_count => 0,
    )
    @container[:backing_ref].should_not be_nil

    # Check the relation to container node
    @container.container_group.should have_attributes(
      :name => "database-1-a20bt"
    )
  end

  def assert_specific_container_group
    @containergroup = ContainerGroup.find_by_name("database-1-a20bt")
    @containergroup.should have_attributes(
      :name           => "database-1-a20bt",
      :restart_policy => "Always",
      :dns_policy     => "ClusterFirst",
    )

    # Check the relation to container node
    @containergroup.container_node.should have_attributes(
      :name => "dhcp-0-129.tlv.redhat.com"
    )

    # Check the relation to containers
    @containergroup.containers.count.should == 1
    @containergroup.containers.last.should have_attributes(
      :name => "ruby-helloworld-database"
    )
  end

  def assert_specific_container_node
    @containernode = ContainerNode.first
    @containernode.should have_attributes(
      :name          => "dhcp-0-129.tlv.redhat.com",
      :lives_on_type => nil,
      :lives_on_id   => nil
    )
  end

  def assert_specific_container_service
    @containersrv = ContainerService.find_by_name("frontend")
    @containersrv.should have_attributes(
      :name             => "frontend",
      :session_affinity => "None",
      :portal_ip        => "172.30.141.69"
    )
  end

  def assert_specific_container_project
    @container_pr = ContainerProject.find_by_name("test")
    @container_pr.should have_attributes(
      :name         => "test",
      :display_name => ""
    )
  end

  def assert_specific_container_route
    @container_route = ContainerRoute.find_by_name("route-edge")
    @container_route.should have_attributes(
      :name      => "route-edge",
      :host_name => "www.example.com"
    )

    @container_route.container_service.should have_attributes(
      :name => "frontend"
    )

    @container_route.container_project.should have_attributes(
      :name    => "test"
    )
  end
end
