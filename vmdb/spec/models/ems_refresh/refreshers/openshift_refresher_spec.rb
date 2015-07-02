require "spec_helper"

describe EmsRefresh::Refreshers::OpenshiftRefresher do
  before(:each) do
    MiqServer.stub(:my_zone).and_return("default")
    @ems = FactoryGirl.create(:ems_openshift, :hostname => "10.35.0.167")
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
    ContainerService.count.should == 4
    ContainerPortConfig.count.should == 1
    ContainerDefinition.count.should == 2
    ContainerRoute.count.should == 1
    ContainerProject.count.should == 3
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
                          :ems_ref       => "6d7f94f4-e386-11e4-9d96-f8b156af4ae1_ruby-helloworld-database_mysql",
                          :name          => "ruby-helloworld-database",
                          :restart_count => 7721,
                          :image         => "mysql",
                          :backing_ref   => "docker://139be9e3f41614fc8212314f44ada59ad6d48a3fd0011aeba37ea3b0e9313f9d"
                      )
  end

  def assert_specific_container_group
    @containergroup = ContainerGroup.find_by_name("database-1-peca1")
    @containergroup.should have_attributes(
                               :ems_ref        => "6d7f94f4-e386-11e4-9d96-f8b156af4ae1",
                               :name           => "database-1-peca1",
                               :restart_policy => "Always",
                               :dns_policy     => "ClusterFirst",
                           )

    # Check the relation to container node
    @containergroup.container_node.should have_attributes(
                                              :ems_ref => "58ffddce-e385-11e4-9d96-f8b156af4ae1"
                                          )
  end

  def assert_specific_container_node
    @containernode = ContainerNode.first
    @containernode.should have_attributes(
                              :ems_ref       => "58ffddce-e385-11e4-9d96-f8b156af4ae1",
                              :name          => "dhcp-0-167.tlv.redhat.com",
                              :lives_on_type => nil,
                              :lives_on_id   => nil
                          )
  end

  def assert_specific_container_service
    @containersrv = ContainerService.find_by_name("frontend")
    @containersrv.should have_attributes(
                             :ems_ref          => "ff7e7aa3-e385-11e4-9d96-f8b156af4ae1",
                             :name             => "frontend",
                             :session_affinity => "None",
                             :portal_ip        => "172.30.208.102"
                         )
  end

  def assert_specific_container_project
    @container_pr = ContainerProject.find_by_name("openshift")
    @container_pr.should have_attributes(
                             :ems_ref => "581874d7-e385-11e4-9d96-f8b156af4ae1",
                             :name    => "openshift"
                         )
  end

  def assert_specific_container_route
    @container_route = ContainerRoute.find_by_name("route-edge")
    @container_route.should have_attributes(
                                :ems_ref      => "ff8a8e45-e385-11e4-9d96-f8b156af4ae1",
                                :name         => "route-edge",
                                :host_name    => "www.example.com",
                                :service_name => "frontend"
                            )
  end
end
