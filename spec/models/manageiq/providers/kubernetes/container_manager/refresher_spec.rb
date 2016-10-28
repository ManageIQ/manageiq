describe ManageIQ::Providers::Kubernetes::ContainerManager::Refresher do
  before(:each) do
    allow(MiqServer).to receive(:my_zone).and_return("default")
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

  it ".ems_type" do
    expect(described_class.ems_type).to eq(:kubernetes)
  end

  # Smoke test the use of ContainerLabelTagMapping during refresh.
  before :each do
    @name_category = FactoryGirl.create(:classification, :name => 'name', :description => 'Name')
    @label_tag_mapping = FactoryGirl.create(
      :container_label_tag_mapping,
      :label_name => 'name', :tag => @name_category.tag
    )
  end

  it "will perform a full refresh on k8s" do
    2.times do # Run twice to verify that a second run with existing data does not change anything
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
      assert_specific_container_definition
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
    expect(ContainerGroup.count).to eq(2)
    expect(ContainerNode.count).to eq(2)
    expect(Container.count).to eq(3)
    expect(ContainerService.count).to eq(5)
    expect(ContainerPortConfig.count).to eq(2)
    expect(ContainerEnvVar.count).to eq(3)
    expect(ContainerDefinition.count).to eq(3)
    expect(ContainerReplicator.count).to eq(2)
    expect(ContainerProject.count).to eq(1)
    expect(ContainerQuota.count).to eq(2)
    expect(ContainerLimit.count).to eq(3)
    expect(ContainerImage.count).to eq(3)
    expect(ContainerImageRegistry.count).to eq(1)
    expect(ContainerComponentStatus.count).to eq(3)
  end

  def assert_ems
    expect(@ems).to have_attributes(
      :port => 6443,
      :type => "ManageIQ::Providers::Kubernetes::ContainerManager"
    )
  end

  def assert_authentication
    expect(@ems.authentication_tokens.count).to eq(1)
    @token = @ems.authentication_tokens.last
    expect(@token).to have_attributes(
      :auth_key => 'valid-token'
    )
  end

  def assert_specific_container
    @container = Container.find_by_name("heapster")
    expect(@container).to have_attributes(
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
      expect(date_.kind_of?(ActiveSupport::TimeWithZone) || date_.kind_of?(NilClass)).to be_truthy
    end

    expect(@container.container_image.name).to eq("kubernetes/heapster")
    expect(@container.container_definition.command).to eq("/heapster --source\\=kubernetes:https://kubernetes "\
                                                      "--sink\\=influxdb:http://monitoring-influxdb:80")

    @container2 = Container.find_by_name("influxdb")
    expect(@container2).to have_attributes(
      # :ems_ref       => "a7649eaa-e73f-11e4-b613-001a4a5f4a02_influxdb_kubernetes/heapster_influxdb:v0.3",
      :name          => "influxdb",
      :restart_count => 0,

    # :backing_ref   => "docker://af741769b650a408f4a65d2d27043912b6d57e5e2a721faeb7a93a1989eef0c6"
    )

    # Check the relation to container group
    expect(@container2.container_group).to have_attributes(
      :name => "monitoring-influx-grafana-controller-22icy"
    )

    # Check relation to provider, container definition and container image
    expect(@container2.container_image.name).to eq("kubernetes/heapster_influxdb")
    expect(@container2.container_definition).not_to be_nil
    expect(@container2.ext_management_system).to eq(@ems)

    expect(@container.container_node).to have_attributes(
      :name => "10.35.0.169"
    )
  end

  def assert_specific_container_definition
    expect(ContainerDefinition.find_by_name("heapster").ext_management_system).to eq(@ems)
  end

  def assert_specific_container_group
    @containergroup = ContainerGroup.find_by_name("monitoring-heapster-controller-4j5zu")
    expect(@containergroup).to have_attributes(
      # :ems_ref        => "49984e80-e1b7-11e4-b7dc-001a4a5f4a02",
      :name           => "monitoring-heapster-controller-4j5zu",
      :restart_policy => "Always",
      :dns_policy     => "ClusterFirst",
      :phase          => "Running",
    )
    expect(@containergroup.labels).to contain_exactly(
      label_with_name_value("name", "heapster")
    )
    expect(@containergroup.tags).to contain_exactly(
      tag_in_category_with_description(@name_category, "heapster")
    )

    # Check the relation to container node
    expect(@containergroup.container_node).not_to be_nil
    # @containergroup.container_node.should have_attributes(:ems_ref => "a3d2a008-e73f-11e4-b613-001a4a5f4a02")

    # Check the relation to container services
    @services = @containergroup.container_services
    expect(@services.count).to eq(1)
    expect(@services.first).to have_attributes(
      # :ems_ref => "49981230-e1b7-11e4-b7dc-001a4a5f4a02",
      :name         => "monitoring-heapster",
      :service_type => "ClusterIP"
    )

    # Check the relation to containers
    expect(@containergroup.containers.count).to eq(1)

    # Check relations to replicator, labels and provider
    expect(@containergroup.container_replicator).to eq(
      ContainerReplicator.find_by(:name => "monitoring-heapster-controller")
    )
    expect(@containergroup.container_replicator.labels).to contain_exactly(
      label_with_name_value("name", "heapster")
    )
    expect(@containergroup.ext_management_system).to eq(@ems)

    # Check pod condition name is "Ready" with status "True"
    @containergroupconditions = ContainerCondition.where(:container_entity_type => "ContainerGroup")
    expect(@containergroupconditions.first).to have_attributes(
      :name   => "Ready",
      :status => "True"
    )
  end

  def assert_specific_container_node
    @containernode = ContainerNode.where(:name => "10.35.0.169").first
    expect(@containernode).to have_attributes(
      # :ems_ref       => "a3d2a008-e73f-11e4-b613-001a4a5f4a02",
      :lives_on_type              => @openstack_vm.type,
      :lives_on_id                => @openstack_vm.id,
      :container_runtime_version  => "docker://1.5.0",
      :kubernetes_kubelet_version => "v1.0.0-dirty",
      :kubernetes_proxy_version   => "v1.0.0-dirty",
      :max_container_groups       => 40
    )

    @containernodeconditions = ContainerCondition.where(:container_entity_type => "ContainerNode")
    expect(@containernodeconditions.count).to eq(2)
    expect(@containernodeconditions.first).to have_attributes(
      :name   => "Ready",
      :status => "True"
    )

    expect(@containernode.labels).to contain_exactly(
      label_with_name_value("kubernetes.io/hostname", "10.35.0.169")
    )

    expect(@containernode.computer_system.operating_system).to have_attributes(
      :distribution   => "Fedora 20 (Heisenbug)",
      :kernel_version => "3.18.9-100.fc20.x86_64"
    )

    expect(@containernode.hardware).to have_attributes(
      :cpu_total_cores => 2,
      :memory_mb       => 2000
    )

    expect(@containernode.ready_condition_status).not_to be_nil
    expect(@containernode.lives_on).to eq(@openstack_vm)
    expect(@containernode.container_groups.count).to eq(2)
    expect(@containernode.ext_management_system).to eq(@ems)

    # Leaving this test commented out until we find a way to test this more easily
    # Check relationship with oVirt provider
    @containernode = ContainerNode.where(:name => "localhost.localdomain").first
    expect(@containernode).to have_attributes(
      :lives_on_type => @ovirt_vm.type,
      :lives_on_id   => @ovirt_vm.id,
    )
    expect(@containernode.lives_on).to eq(@ovirt_vm)
    expect(@containernode.containers.count).to eq(0)
    expect(@containernode.container_routes.count).to eq(0)
  end

  def assert_specific_container_service
    @containersrv = ContainerService.find_by_name("kubernetes")
    expect(@containersrv).to have_attributes(
      # :ems_ref          => "a36a2858-e73f-11e4-b613-001a4a5f4a02",
      :name             => "kubernetes",
      :session_affinity => "None",
      :portal_ip        => "10.0.0.1",
    )
    expect(@containersrv.labels).to contain_exactly(
      label_with_name_value("provider", "kubernetes"),
      label_with_name_value("component", "apiserver")
    )
    expect(@containersrv.selector_parts.count).to eq(0)

    @confs = @containersrv.container_service_port_configs
    expect(@confs.count).to eq(1)
    @confs = @confs.first
    expect(@confs).to have_attributes(
      :name        => nil,
      :protocol    => "TCP",
      :port        => 443,
      :target_port => "443",
      :node_port   => nil
    )

    # Check group relation
    @groups = ContainerService.find_by_name("monitoring-influxdb-ui").container_groups
    expect(@groups.count).to eq(1)
    @group = @groups.first
    expect(@group).to have_attributes(
      # :ems_ref => "49b72714-e1b7-11e4-b7dc-001a4a5f4a02",
      # :name    => "monitoring-influx-grafana-controller-2toua"
      :restart_policy => "Always",
      :dns_policy     => "ClusterFirst"
    )

    expect(@containersrv.ext_management_system).to eq(@ems)
    expect(@containersrv.container_nodes.count).to eq(0)
  end

  def assert_specific_container_replicator
    @replicator = ContainerReplicator.where(:name => "monitoring-influx-grafana-controller").first
    expect(@replicator).to have_attributes(
      :name             => "monitoring-influx-grafana-controller",
      :replicas         => 1,
      :current_replicas => 1
    )
    expect(@replicator.labels).to contain_exactly(
      label_with_name_value("name", "influxGrafana")
    )
    expect(@replicator.tags).to contain_exactly(
      tag_in_category_with_description(@name_category, "influxGrafana")
    )
    expect(@replicator.selector_parts.count).to eq(1)

    @group = ContainerGroup.where(:name => "monitoring-influx-grafana-controller-22icy").first
    expect(@group.container_replicator).not_to be_nil
    expect(@group.container_replicator.name).to eq("monitoring-influx-grafana-controller")
    expect(@replicator.ext_management_system).to eq(@ems)

    expect(@replicator.container_nodes.count).to eq(1)
    expect(@replicator.container_nodes.first).to have_attributes(
      :name => "10.35.0.169"
    )
  end

  def assert_specific_container_project
    @container_pr = ContainerProject.find_by_name("default")
    expect(@container_pr).to have_attributes(
      :name         => "default",
      :display_name => nil
    )

    expect(@container_pr.container_groups.count).to eq(2)
    expect(@container_pr.container_replicators.count).to eq(2)
    expect(@container_pr.container_nodes.count).to eq(1)
    expect(@container_pr.container_services.count).to eq(5)
    expect(@container_pr.ext_management_system).to eq(@ems)
  end

  def assert_specific_container_quota
    container_quota = ContainerQuota.find_by_name("quota")
    container_quota.ems_created_on.kind_of?(ActiveSupport::TimeWithZone)
    expect(container_quota.container_quota_items.count).to eq(8)
    cpu_quota = container_quota.container_quota_items.select { |x| x[:resource] == 'cpu' }[0]
    expect(cpu_quota).to have_attributes(
      :quota_desired  => '20',
      :quota_enforced => '20',
      :quota_observed => '100m',
    )
    expect(container_quota.container_project.name).to eq("default")
  end

  def assert_specific_container_limit
    container_limit = ContainerLimit.find_by_name("limits")
    container_limit.ems_created_on.kind_of?(ActiveSupport::TimeWithZone)
    expect(container_limit.container_limit_items.count).to eq(2)
    expect(container_limit.container_project.name).to eq("default")
    item = container_limit.container_limit_items.each { |x| x[:item_type] == 'Container' && x[:resource] == 'cpu' }[0]
    assert_specific_limit_item item
  end

  def assert_specific_limit_item(item)
    expect(item).to have_attributes(
      :max                     => nil,
      :min                     => nil,
      :default                 => "100m",
      :default_request         => nil,
      :max_limit_request_ratio => nil,
    )
  end

  def assert_specific_container_image_and_registry
    @image = ContainerImage.where(:name => "kubernetes/heapster").first
    expect(@image).to have_attributes(
      :name      => "kubernetes/heapster",
      :tag       => "v0.16.0",
      :image_ref => "docker://f79cf2701046bea8d5f1384f7efe79dd4d20620b3594fff5be39142fa862259d",
    )

    expect(@image.container_image_registry).not_to be_nil
    expect(@image.container_image_registry).to have_attributes(
      :host => "example.com",
      :port => "1234",
    )
    expect(@image.container_nodes.count).to eq(1)
  end

  def assert_specific_container_component_status
    @component_status = ContainerComponentStatus.find_by_name("etcd-0")
    expect(@component_status).to have_attributes(
      :condition => "Healthy",
      :status    => "True"
    )
  end

  def label_with_name_value(name, value)
    an_object_having_attributes(
      :section => 'labels', :source => 'kubernetes',
      :name => name, :value => value
    )
  end

  def tag_in_category_with_description(category, description)
    satisfy { |tag| tag.category == category && tag.classification.description == description }
  end
end
