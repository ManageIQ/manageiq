require "spec_helper"

describe EmsRefresh::Refreshers::KubernetesRefresher do
  before(:each) do
    MiqServer.stub(:my_zone).and_return("default")
    @ems = FactoryGirl.create(:ems_kubernetes, :hostname => "10.35.0.202", :ipaddress => "10.35.0.202", :port => 6443)
  end

  it "will perform a full refresh on k8s" do
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

  end

  def assert_table_counts
    ContainerGroup.count.should        == 2
    ContainerNode.count.should         == 1
    Container.count.should             == 3
    ContainerService.count.should      == 6
    ContainerPortConfig.count.should   == 3
    ContainerDefinition.count.should   == 3
  end

  def assert_ems
    @ems.should have_attributes(
      :port => "6443",
      :type => "EmsKubernetes"
    )
  end

  def assert_specific_container
    @container = Container.find_by_name("heapster")
    @container.should have_attributes(
      :ems_ref       => "49984e80-e1b7-11e4-b7dc-001a4a5f4a02_heapster_kubernetes/heapster:v0.9",
      :name          => "heapster",
      :restart_count => 0,
      :image         => "kubernetes/heapster:v0.9",
      :backing_ref   => "docker://87cd51044d7175c246fa1fa7699253fc2aecb769021837a966fa71e9dcb54d71"
    )

    @container2 = Container.find_by_name("influxdb")
    @container2.should have_attributes(
      :ems_ref       => "49b72714-e1b7-11e4-b7dc-001a4a5f4a02_influxdb_kubernetes/heapster_influxdb:v0.3",
      :name          => "influxdb",
      :restart_count => 0,
      :image         => "kubernetes/heapster_influxdb:v0.3",
      :backing_ref   => "docker://af741769b650a408f4a65d2d27043912b6d57e5e2a721faeb7a93a1989eef0c6"
    )
  end

  def assert_specific_container_group
    @containergroup = ContainerGroup.find_by_name("monitoring-heapster-controller-40yp7")
    @containergroup.should have_attributes(
      :ems_ref        => "49984e80-e1b7-11e4-b7dc-001a4a5f4a02",
      :name           => "monitoring-heapster-controller-40yp7",
      :restart_policy => "Always",
      :dns_policy     => "ClusterFirst",
    )

    # Check the relation to container node
    @containergroup.container_node.should have_attributes(
      :ems_ref => "f035c16a-e1b5-11e4-b7dc-001a4a5f4a02"
    )

    # Check the relation to container services
    @services = @containergroup.container_services
    @services.count.should == 1
    @services.first.should have_attributes(
      :ems_ref => "49981230-e1b7-11e4-b7dc-001a4a5f4a02",
      :name    => "monitoring-heapster"
    )
  end

  def assert_specific_container_node
    @containernode = ContainerNode.first
    @containernode.should have_attributes(
      :ems_ref       => "f035c16a-e1b5-11e4-b7dc-001a4a5f4a02",
      :lives_on_type => nil,
      :lives_on_id   => nil
    )
  end

  def assert_specific_container_service
    @containersrv = ContainerService.find_by_name("kubernetes")
    @containersrv.should have_attributes(
      :ems_ref          => "ef9ca891-e1b5-11e4-b7dc-001a4a5f4a02",
      :name             => "kubernetes",
      :session_affinity => "None",
      :portal_ip        => "10.0.0.2",
      :protocol         => "TCP",
      :port             => 443
    )

    # Check group relation
    @groups = ContainerService.find_by_name("monitoring-influxdb-ui").container_groups
    @groups.count.should  == 1
    @group = @groups.first
    @group.should have_attributes(
      :ems_ref => "49b72714-e1b7-11e4-b7dc-001a4a5f4a02",
      :name    => "monitoring-influx-grafana-controller-2toua"
    )
  end
end
