require "spec_helper"

describe ManageIQ::Providers::Kubernetes::ContainerManager::Refresher do
  before(:each) do
    MiqServer.stub(:my_zone).and_return("default")
    auth = AuthToken.new(:name => "test", :auth_key => "valid-token")
    @ems = FactoryGirl.create(:ems_kubernetes, :hostname => "10.35.0.169",
                              :ipaddress => "10.35.0.169", :port => 6443,
                              :authentications => [auth])
    # NOTE: the following :uid_ems should match (downcased) the kubernetes
    #       node systemUUID in the VCR yaml file
    @openstack_vm = FactoryGirl.create(
      :vm_openstack,
      :uid_ems => '8b6c7070-9abd-41ac-a950-e4cfac665673')
    @ovirt_vm = FactoryGirl.create(
      :vm_redhat,
      :uid_ems => 'cad16607-fb88-4412-a993-5242030f6afa')
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
      assert_specific_container_quota
      assert_specific_container_limit
      assert_specific_container_image_and_registry
      assert_specific_container_component_status
    end
  end

  def assert_table_counts
    ContainerGroup.count.should == 2
    ContainerNode.count.should == 2
    Container.count.should == 3
    ContainerService.count.should == 5
    ContainerPortConfig.count.should == 2
    ContainerEnvVar.count.should == 3
    ContainerDefinition.count.should == 3
    ContainerReplicator.count.should == 2
    ContainerProject.count.should == 1
    ContainerQuota.count.should == 2
    ContainerLimit.count.should == 3
    ContainerImage.count.should == 3
    ContainerImageRegistry.count.should == 1
    ContainerComponentStatus.count.should == 3
  end

  def assert_ems
    @ems.should have_attributes(
      :port => "6443",
      :type => "ManageIQ::Providers::Kubernetes::ContainerManager"
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
      # :ems_ref     => "a7566742-e73f-11e4-b613-001a4a5f4a02_heapster_kubernetes/heapster:v0.9",
      :name          => "heapster",
      :restart_count => 2,
      :state         => "running",
      :last_state    => "terminated",
    # :backing_ref => "docker://87cd51044d7175c246fa1fa7699253fc2aecb769021837a966fa71e9dcb54d71"
    )

    [
      @container.started_at,
      @container.finished_at,
      @container.last_started_at,
      @container.last_finished_at,
    ].each do |date_|
      (date_.kind_of?(ActiveSupport::TimeWithZone) || date_.kind_of?(NilClass)).should be_true
    end

    @container.container_image.name.should == "kubernetes/heapster"
    @container.container_definition.command.should == "/heapster --source\\=kubernetes:https://kubernetes "\
                                                      "--sink\\=influxdb:http://monitoring-influxdb:80"

    @container2 = Container.find_by_name("influxdb")
    @container2.should have_attributes(
      # :ems_ref       => "a7649eaa-e73f-11e4-b613-001a4a5f4a02_influxdb_kubernetes/heapster_influxdb:v0.3",
      :name          => "influxdb",
      :restart_count => 0,

    # :backing_ref   => "docker://af741769b650a408f4a65d2d27043912b6d57e5e2a721faeb7a93a1989eef0c6"
    )

    # Check the relation to container group
    @container2.container_group.should have_attributes(
      :name => "monitoring-influx-grafana-controller-22icy"
    )

    # Check relation to provider, container definition and container image
    @container2.container_image.name.should == "kubernetes/heapster_influxdb"
    @container2.container_definition.should_not be_nil
    @container2.ext_management_system.should == @ems

    @container.container_node.should have_attributes(
      :name => "10.35.0.169"
    )
  end

  def assert_specific_container_group
    @containergroup = ContainerGroup.find_by_name("monitoring-heapster-controller-4j5zu")
    @containergroup.should have_attributes(
      # :ems_ref        => "49984e80-e1b7-11e4-b7dc-001a4a5f4a02",
      :name           => "monitoring-heapster-controller-4j5zu",
      :restart_policy => "Always",
      :dns_policy     => "ClusterFirst",
      :phase          => "Running",
    )
    @containergroup.labels.count.should == 1

    # Check the relation to container node
    @containergroup.container_node.should_not be_nil
    # @containergroup.container_node.should have_attributes(:ems_ref => "a3d2a008-e73f-11e4-b613-001a4a5f4a02")

    # Check the relation to container services
    @services = @containergroup.container_services
    @services.count.should == 1
    @services.first.should have_attributes(
      # :ems_ref => "49981230-e1b7-11e4-b7dc-001a4a5f4a02",
      :name         => "monitoring-heapster",
      :service_type => "ClusterIP"
    )

    # Check the relation to containers
    @containergroup.containers.count.should == 1

    # Check relations to replicator, labels and provider
    @containergroup.container_replicator.should ==
      ContainerReplicator.find_by(:name => "monitoring-heapster-controller")
    @containergroup.ext_management_system.should == @ems

    # Check pod condition name is "Ready" with status "True"
    @containergroupconditions = ContainerCondition.where(:container_entity_type => "ContainerGroup")
    @containergroupconditions.first.should have_attributes(
      :name   => "Ready",
      :status => "True"
    )
  end

  def assert_specific_container_node
    @containernode = ContainerNode.where(:name => "10.35.0.169").first
    @containernode.should have_attributes(
      # :ems_ref       => "a3d2a008-e73f-11e4-b613-001a4a5f4a02",
      :lives_on_type              => @openstack_vm.type,
      :lives_on_id                => @openstack_vm.id,
      :container_runtime_version  => "docker://1.5.0",
      :kubernetes_kubelet_version => "v1.0.0-dirty",
      :kubernetes_proxy_version   => "v1.0.0-dirty",
      :max_container_groups       => 40
    )

    @containernodeconditions = ContainerCondition.where(:container_entity_type => "ContainerNode")
    @containernodeconditions.count.should be == 2
    @containernodeconditions.first.should have_attributes(
      :name   => "Ready",
      :status => "True"
    )

    @containernode.labels.count.should == 1

    @containernode.computer_system.operating_system.should have_attributes(
      :distribution   => "Fedora 20 (Heisenbug)",
      :kernel_version => "3.18.9-100.fc20.x86_64"
    )

    @containernode.hardware.should have_attributes(
      :cpu_total_cores => 2,
      :memory_mb       => 2000
    )

    @containernode.ready_condition_status.should_not be_nil
    @containernode.lives_on.should == @openstack_vm
    @containernode.container_groups.count.should == 2
    @containernode.ext_management_system.should == @ems

    # Leaving this test commented out until we find a way to test this more easily
    # Check relationship with oVirt provider
    @containernode = ContainerNode.where(:name => "localhost.localdomain").first
    @containernode.should have_attributes(
      :lives_on_type => @ovirt_vm.type,
      :lives_on_id   => @ovirt_vm.id,
    )
    @containernode.lives_on.should == @ovirt_vm
    @containernode.containers.count.should == 0
    @containernode.container_routes.count.should == 0
  end

  def assert_specific_container_service
    @containersrv = ContainerService.find_by_name("kubernetes")
    @containersrv.should have_attributes(
      # :ems_ref          => "a36a2858-e73f-11e4-b613-001a4a5f4a02",
      :name             => "kubernetes",
      :session_affinity => "None",
      :portal_ip        => "10.0.0.1",
    )
    @containersrv.labels.count.should == 2
    @containersrv.selector_parts.count.should == 0

    @confs = @containersrv.container_service_port_configs
    @confs.count.should == 1
    @confs = @confs.first
    @confs.should have_attributes(
      :name        => nil,
      :protocol    => "TCP",
      :port        => 443,
      :target_port => "443",
      :node_port   => nil
    )

    # Check group relation
    @groups = ContainerService.find_by_name("monitoring-influxdb-ui").container_groups
    @groups.count.should == 1
    @group = @groups.first
    @group.should have_attributes(
      # :ems_ref => "49b72714-e1b7-11e4-b7dc-001a4a5f4a02",
      # :name    => "monitoring-influx-grafana-controller-2toua"
      :restart_policy => "Always",
      :dns_policy     => "ClusterFirst"
    )

    @containersrv.ext_management_system.should == @ems
    @containersrv.container_nodes.count.should == 0
  end

  def assert_specific_container_replicator
    @replicator = ContainerReplicator.where(:name => "monitoring-influx-grafana-controller").first
    @replicator.should have_attributes(
      :name             => "monitoring-influx-grafana-controller",
      :replicas         => 1,
      :current_replicas => 1
    )
    @replicator.labels.count.should == 1
    @replicator.selector_parts.count.should == 1

    @group = ContainerGroup.where(:name => "monitoring-influx-grafana-controller-22icy").first
    @group.container_replicator.should_not be_nil
    @group.container_replicator.name.should == "monitoring-influx-grafana-controller"
    @replicator.ext_management_system.should == @ems

    @replicator.container_nodes.count.should == 1
    @replicator.container_nodes.first.should have_attributes(
      :name => "10.35.0.169"
    )
  end

  def assert_specific_container_project
    @container_pr = ContainerProject.find_by_name("default")
    @container_pr.should have_attributes(
      :name         => "default",
      :display_name => nil
    )

    @container_pr.container_groups.count.should == 2
    @container_pr.container_replicators.count.should == 2
    @container_pr.container_nodes.count.should == 1
    @container_pr.container_services.count.should == 5
    @container_pr.ext_management_system.should == @ems
  end

  def assert_specific_container_quota
    container_quota = ContainerQuota.find_by_name("quota")
    container_quota.creation_timestamp.kind_of?(ActiveSupport::TimeWithZone)
    container_quota.container_quota_items.count.should == 8
    cpu_quota = container_quota.container_quota_items.select { |x| x[:resource] == 'cpu' }[0]
    cpu_quota.should have_attributes(
      :quota_desired  => '20',
      :quota_enforced => '20',
      :quota_observed => '100m',
    )
    container_quota.container_project.name.should == "default"
  end

  def assert_specific_container_limit
    container_limit = ContainerLimit.find_by_name("limits")
    container_limit.creation_timestamp.kind_of?(ActiveSupport::TimeWithZone)
    container_limit.container_limit_items.count.should == 2
    container_limit.container_project.name.should == "default"
    item = container_limit.container_limit_items.each { |x| x[:item_type] == 'Container' && x[:resource] == 'cpu' }[0]
    assert_specific_limit_item item
  end

  def assert_specific_limit_item(item)
    item.should have_attributes(
      :max                     => nil,
      :min                     => nil,
      :default                 => "100m",
      :default_request         => nil,
      :max_limit_request_ratio => nil,
    )
  end

  def assert_specific_container_image_and_registry
    @image = ContainerImage.where(:name => "kubernetes/heapster").first
    @image.should have_attributes(
      :name      => "kubernetes/heapster",
      :tag       => "v0.16.0",
      :image_ref => "docker://f79cf2701046bea8d5f1384f7efe79dd4d20620b3594fff5be39142fa862259d",
    )

    @image.container_image_registry.should_not be_nil
    @image.container_image_registry.should have_attributes(
      :host => "example.com",
      :port => "1234",
    )
    @image.container_nodes.count.should == 1
  end

  def assert_specific_container_component_status
    @component_status = ContainerComponentStatus.find_by_name("etcd-0")
    @component_status.should have_attributes(
      :condition => "Healthy",
      :status    => "True"
    )
  end
end
