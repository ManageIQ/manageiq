require "spec_helper"

describe EmsRefresh::Refreshers::KubernetesRefresher do
  before(:each) do
    MiqServer.stub(:my_zone).and_return("default")
    auth = AuthToken.new(:name => "test", :auth_key => "valid-token")
    @ems = FactoryGirl.create(:ems_kubernetes, :hostname => "10.35.0.202",
                              :ipaddress => "10.35.0.202", :port => 6443,
                              :authentications => [auth])
    # NOTE: the following :uid_ems should match (downcased) the kubernetes
    #       node systemUUID in the VCR yaml file
    @openstack_vm = FactoryGirl.create(
      :vm_openstack,
      :uid_ems => '7781b4be-f7b9-439f-92af-fb710a6311e0')
  end

  it "will perform a full refresh on k8s" do
    2.times do  # Run twice to verify that a second run with existing data does not change anything
      VCR.use_cassette("#{described_class.name.underscore}") do # , :record => :new_episodes) do
        EmsRefresh.refresh(@ems)
      end
      @ems.reload

      # All ems_ref fields and other auto generated fields aren't checked because the VCR file needs update
      # every time the api changes. Until the api stabilizes, the tests on those fields are commented out.
      assert_ems
      assert_authentication
      assert_table_counts
      assert_specific_container
      assert_specific_container_group
      assert_specific_container_node
      assert_specific_container_service
      assert_specific_container_replicator
      assert_specific_container_project
    end
  end

  def assert_table_counts
    ContainerGroup.count.should == 2
    ContainerNode.count.should == 1
    Container.count.should == 3
    ContainerService.count.should == 6
    ContainerPortConfig.count.should == 2
    ContainerEnvVar.count.should == 5
    ContainerDefinition.count.should == 3
    ContainerReplicator.count.should == 2
    ContainerProject.count.should == 1
  end

  def assert_ems
    @ems.should have_attributes(
      :port => "6443",
      :type => "EmsKubernetes"
    )
  end

  def assert_authentication
    @ems.authentication_tokens.count.should == 1
    @token = @ems.authentication_tokens.last
    @token.should have_attributes(
      :auth_key => 'valid-token'
    )
  end

  def assert_specific_container
    @container = Container.find_by_name("heapster")
    @container.should have_attributes(
      # :ems_ref       => "a7566742-e73f-11e4-b613-001a4a5f4a02_heapster_kubernetes/heapster:v0.9",
      :name          => "heapster",
      :restart_count => 0,
      :image         => "kubernetes/heapster:v0.11.0",
      # :backing_ref   => "docker://87cd51044d7175c246fa1fa7699253fc2aecb769021837a966fa71e9dcb54d71"
    )

    @container2 = Container.find_by_name("influxdb")
    @container2.should have_attributes(
      # :ems_ref       => "a7649eaa-e73f-11e4-b613-001a4a5f4a02_influxdb_kubernetes/heapster_influxdb:v0.3",
      :name          => "influxdb",
      :restart_count => 0,
      :image         => "kubernetes/heapster_influxdb:v0.3",
      # :backing_ref   => "docker://af741769b650a408f4a65d2d27043912b6d57e5e2a721faeb7a93a1989eef0c6"
    )
  end

  def assert_specific_container_group
    @containergroup = ContainerGroup.find_by_name("monitoring-heapster-controller-39o8t")
    @containergroup.should have_attributes(
      # :ems_ref        => "49984e80-e1b7-11e4-b7dc-001a4a5f4a02",
      :name           => "monitoring-heapster-controller-39o8t",
      :restart_policy => "Always",
      :dns_policy     => "ClusterFirst",
    )

    # Check the relation to container node
    @containergroup.container_node.should_not be_nil
    # @containergroup.container_node.should have_attributes(:ems_ref => "a3d2a008-e73f-11e4-b613-001a4a5f4a02")

    # Check the relation to container services
    @services = @containergroup.container_services
    @services.count.should == 1
    @services.first.should have_attributes(
      # :ems_ref => "49981230-e1b7-11e4-b7dc-001a4a5f4a02",
      :name    => "monitoring-heapster"
    )
  end

  def assert_specific_container_node
    @containernode = ContainerNode.first
    @containernode.should have_attributes(
      # :ems_ref       => "a3d2a008-e73f-11e4-b613-001a4a5f4a02",
      :lives_on_type              => @openstack_vm.type,
      :lives_on_id                => @openstack_vm.id,
      :container_runtime_version  => "docker://1.5.0-dev",
      :kubernetes_kubelet_version => "v0.17.0-441-g6b6b47a777b480",
      :kubernetes_proxy_version   => "v0.17.0-441-g6b6b47a777b480"
    )
    @containernode.container_node_conditions.count.should == 1
    @containernode.container_node_conditions.first.should have_attributes(
      :name   => "Ready",
      :status => "True"
    )
    @containernode.computer_system.operating_system.should have_attributes(
      :distribution   => "CentOS Linux 7 (Core)",
      :kernel_version => "3.10.0-229.1.2.el7.x86_64"
    )
    @containernode.lives_on.should == @openstack_vm
  end

  def assert_specific_container_service
    @containersrv = ContainerService.find_by_name("kubernetes")
    @containersrv.should have_attributes(
      # :ems_ref          => "a36a2858-e73f-11e4-b613-001a4a5f4a02",
      :name             => "kubernetes",
      :session_affinity => "None",
      :portal_ip        => "10.0.0.2",
    )

    @confs = @containersrv.container_service_port_configs
    @confs.count.should  == 1
    @confs = @confs.first
    @confs.should have_attributes(
      :name        => nil,
      :port        => 443,
      :target_port => "443",
      :protocol    => "TCP"
    )

    # Check group relation
    @groups = ContainerService.find_by_name("monitoring-influxdb-ui").container_groups
    @groups.count.should  == 1
    @group = @groups.first
    @group.should have_attributes(
      # :ems_ref => "49b72714-e1b7-11e4-b7dc-001a4a5f4a02",
      # :name    => "monitoring-influx-grafana-controller-2toua"
      :restart_policy => "Always",
      :dns_policy     => "ClusterFirst"
    )
  end

  def assert_specific_container_replicator
    @replicator = ContainerReplicator.where(:name => "monitoring-influx-grafana-controller").first
    @replicator.should have_attributes(
      :name             => "monitoring-influx-grafana-controller",
      :replicas         => 1,
      :current_replicas => 1
    )
    @replicator.container_groups.count.should == 1

    @group = ContainerGroup.where(:name => "monitoring-influx-grafana-controller-mdyqf").first
    @group.container_replicator.should_not be_nil
    @group.container_replicator.name.should == "monitoring-influx-grafana-controller"
  end

  def assert_specific_container_project
    @container_pr = ContainerProject.find_by_name("default")
    @container_pr.should have_attributes(
      # :ems_ref => "581874d7-e385-11e4-9d96-f8b156af4ae1",
      :name    => "default"
    )
  end
end
