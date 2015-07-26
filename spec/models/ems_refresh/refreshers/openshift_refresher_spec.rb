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
    ContainerGroup.count.should == 2
    ContainerNode.count.should == 1
    Container.count.should == 2
    ContainerService.count.should == 5
    ContainerPortConfig.count.should == 2
    ContainerDefinition.count.should == 2
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
      :ems_ref       => "fc73bb4b-2870-11e5-b5bb-727174f8ab71_ruby-helloworld-database_openshift/mysql-55-centos7",
      :name          => "ruby-helloworld-database",
      :restart_count => 0,
      :image         => "openshift/mysql-55-centos7",
      :backing_ref   => "docker://bb608fb1575bcc1a5326517e6c4589df5160fa804daaa4990e837f1154f1c3c9"
    )

    # Check the relation to container node
    @container.container_group.should have_attributes(
      :ems_ref => "fc73bb4b-2870-11e5-b5bb-727174f8ab71"
    )
  end

  def assert_specific_container_group
    @containergroup = ContainerGroup.find_by_name("database-1-3v6zu")
    @containergroup.should have_attributes(
      :ems_ref        => "fc73bb4b-2870-11e5-b5bb-727174f8ab71",
      :name           => "database-1-3v6zu",
      :restart_policy => "Always",
      :dns_policy     => "ClusterFirst",
    )

    # Check the relation to container node
    @containergroup.container_node.should have_attributes(
      :ems_ref => "248c52a3-286d-11e5-b5bb-727174f8ab71"
    )

    # Check the relation to containers
    @containergroup.containers.count.should == 1
    @containergroup.containers.last.should have_attributes(
      :ems_ref => "fc73bb4b-2870-11e5-b5bb-727174f8ab71_ruby-helloworld-database_openshift/mysql-55-centos7"
    )
  end

  def assert_specific_container_node
    @containernode = ContainerNode.first
    @containernode.should have_attributes(
      :ems_ref       => "248c52a3-286d-11e5-b5bb-727174f8ab71",
      :name          => "dhcp-0-129.tlv.redhat.com",
      :lives_on_type => nil,
      :lives_on_id   => nil
    )
  end

  def assert_specific_container_service
    @containersrv = ContainerService.find_by_name("frontend")
    @containersrv.should have_attributes(
      :ems_ref          => "f3a3e170-2870-11e5-b5bb-727174f8ab71",
      :name             => "frontend",
      :session_affinity => "None",
      :portal_ip        => "172.30.187.127"
    )
  end

  def assert_specific_container_project
    @container_pr = ContainerProject.find_by_name("test")
    @container_pr.should have_attributes(
      :ems_ref      => "9f2f3e05-286d-11e5-b5bb-727174f8ab71",
      :name         => "test",
      :display_name => ""
    )
  end

  def assert_specific_container_route
    @container_route = ContainerRoute.find_by_name("route-edge")
    @container_route.should have_attributes(
      :ems_ref   => "f3b59d42-2870-11e5-b5bb-727174f8ab71",
      :name      => "route-edge",
      :host_name => "www.example.com"
    )

    @container_route.container_service.should have_attributes(
      :name => "frontend"
    )

    @container_route.container_project.should have_attributes(
      :ems_ref => "9f2f3e05-286d-11e5-b5bb-727174f8ab71",
      :name    => "test"
    )
  end
end
