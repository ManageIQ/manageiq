describe ManageIQ::Providers::Openshift::ContainerManager::Refresher do
  before(:each) do
    allow(MiqServer).to receive(:my_zone).and_return("default")
    hostname = 'host.example.com'
    token = 'theToken'

    @ems = FactoryGirl.create(
      :ems_openshift,
      :name                      => 'OpenShiftProvider',
      :connection_configurations => [{:endpoint       => {:role     => :default,
                                                          :hostname => hostname,
                                                          :port     => "8443"},
                                      :authentication => {:role     => :bearer,
                                                          :auth_key => token,
                                                          :userid   => "_"}},
                                     {:endpoint       => {:role     => :hawkular,
                                                          :hostname => hostname,
                                                          :port     => "443"},
                                      :authentication => {:role     => :hawkular,
                                                          :auth_key => token,
                                                          :userid   => "_"}}]
    )
  end

  it ".ems_type" do
    expect(described_class.ems_type).to eq(:openshift)
  end

  it "will perform a full refresh on openshift" do
    2.times do
      @ems.reload
      VCR.use_cassette(described_class.name.underscore,
                       :match_requests_on => [:path,]) do # , :record => :new_episodes) do
        EmsRefresh.refresh(@ems)
      end
      @ems.reload

      assert_ems
      assert_table_counts
      assert_specific_container
      assert_specific_container_group
      assert_specific_container_node
      assert_specific_container_services
      assert_specific_container_image_registry
      assert_specific_container_project
      assert_specific_container_route
      assert_specific_container_build
      assert_specific_container_build_pod
      assert_specific_container_template
      assert_specific_container_image
      assert_specific_container_node_custom_attributes
    end
  end

  it "will skip additional attributes when hawk connection fails" do
    hostname = 'host2.example.com'
    token = 'theToken'

    ems = FactoryGirl.create(
      :ems_openshift,
      :name                      => 'OpenShiftProvider2',
      :connection_configurations => [{:endpoint       => {:role     => :default,
                                                          :hostname => hostname,
                                                          :port     => "8443"},
                                      :authentication => {:role     => :bearer,
                                                          :auth_key => token,
                                                          :userid   => "_"}},
                                     {:endpoint       => {:role     => :hawkular,
                                                          :hostname => 'badHost',
                                                          :port     => "443"},
                                      :authentication => {:role     => :hawkular,
                                                          :auth_key => "BadToken",
                                                          :userid   => "_"}}]
    )

    ems.reload
    VCR.use_cassette("#{described_class.name.underscore}_hawk_fails",
                     :match_requests_on => [:path,]) do # , :record => :new_episodes) do
      EmsRefresh.refresh(ems)
    end
    ems.reload

    assert_container_node_with_no_hawk_attributes
  end

  def assert_table_counts
    expect(ContainerGroup.count).to eq(20)
    expect(ContainerNode.count).to eq(2)
    expect(Container.count).to eq(20)
    expect(ContainerService.count).to eq(12)
    expect(ContainerPortConfig.count).to eq(23)
    expect(ContainerDefinition.count).to eq(20)
    expect(ContainerRoute.count).to eq(6)
    expect(ContainerProject.count).to eq(9)
    expect(ContainerBuild.count).to eq(3)
    expect(ContainerBuildPod.count).to eq(3)
    expect(ContainerTemplate.count).to eq(26)
    expect(ContainerImage.count).to eq(44)
  end

  def assert_ems
    expect(@ems).to have_attributes(
      :port => 8443,
      :type => "ManageIQ::Providers::Openshift::ContainerManager"
    )
  end

  def assert_specific_container
    @container = Container.find_by(:name => "deployer")
    expect(@container).to have_attributes(
      :name          => "deployer",
      :restart_count => 0,
    )
    expect(@container[:backing_ref]).not_to be_nil

    # Check the relation to container node
    expect(@container.container_group).to have_attributes(
      :name => "metrics-deployer-frcf1"
    )
  end

  def assert_specific_container_group
    @containergroup = ContainerGroup.find_by(:name => "metrics-deployer-frcf1")
    expect(@containergroup).to have_attributes(
      :name           => "metrics-deployer-frcf1",
      :restart_policy => "Never",
      :dns_policy     => "ClusterFirst",
    )

    # Check the relation to container node
    expect(@containergroup.container_node).to have_attributes(
      :name => "host2.example.com"
    )

    # Check the relation to containers
    expect(@containergroup.containers.count).to eq(1)
    expect(@containergroup.containers.last).to have_attributes(
      :name => "deployer"
    )

    expect(@containergroup.container_project).to eq(ContainerProject.find_by(:name => "openshift-infra"))
    expect(@containergroup.ext_management_system).to eq(@ems)
  end

  def assert_specific_container_node
    @containernode = ContainerNode.first
    expect(@containernode).to have_attributes(
      :name          => "host.example.com",
      :lives_on_type => nil,
      :lives_on_id   => nil
    )

    expect(@containernode.ext_management_system).to eq(@ems)
  end

  def assert_specific_container_node_custom_attributes
    @customattribute = CustomAttribute.find_by(:name => "test_attribute")
    expect(@customattribute).to have_attributes(
      :name          => "test_attribute",
      :value         => "test-value",
      :resource_type => "ContainerNode"
    )

    expect(ContainerNode.find(@customattribute.resource_id)).to eq(@containernode)
  end

  def assert_specific_container_services
    @containersrv = ContainerService.find_by(:name => "kubernetes")
    expect(@containersrv).to have_attributes(
      :name             => "kubernetes",
      :session_affinity => "ClientIP",
      :portal_ip        => "172.30.0.1"
    )

    expect(@containersrv.container_project).to eq(ContainerProject.find_by(:name => "default"))
    expect(@containersrv.ext_management_system).to eq(@ems)
    expect(@containersrv.container_image_registry).to be_nil
  end

  def assert_specific_container_image_registry
    expect(ContainerService.find_by(:name => "docker-registry").container_image_registry.name). to eq("172.30.190.81")
  end

  def assert_specific_container_image_registry
    @registry = ContainerImageRegistry.find_by(:name => "172.30.190.81")
    expect(@registry).to have_attributes(
      :name => "172.30.190.81",
      :host => "172.30.190.81",
      :port => "5000"
    )
    expect(@registry.container_services.first.name).to eq("docker-registry")
  end

  def assert_specific_container_project
    @container_pr = ContainerProject.find_by(:name => "default")
    expect(@container_pr).to have_attributes(
      :name         => "default",
      :display_name => nil
    )

    expect(@container_pr.container_groups.count).to eq(3)
    expect(@container_pr.container_routes.count).to eq(2)
    expect(@container_pr.container_replicators.count).to eq(4)
    expect(@container_pr.container_services.count).to eq(4)
    expect(@container_pr.ext_management_system).to eq(@ems)
  end

  def assert_specific_container_route
    @container_route = ContainerRoute.find_by(:name => "registry-console")
    expect(@container_route).to have_attributes(
      :name      => "registry-console",
      :host_name => "registry-console-default.router.default.svc.cluster.local"
    )

    expect(@container_route.container_service).to have_attributes(
      :name => "registry-console"
    )

    expect(@container_route.container_project).to have_attributes(
      :name    => "default"
    )

    expect(@container_route.ext_management_system).to eq(@ems)
  end

  def assert_specific_container_build
    @container_build = ContainerBuild.find_by(:name => "python-project")
    expect(@container_build).to have_attributes(
      :name              => "python-project",
      :build_source_type => "Git",
      :source_git        => "https://github.com/openshift/django-ex.git",
      :output_name       => "python-project:latest",
    )

    expect(@container_build.container_project).to eq(ContainerProject.find_by(:name => "python-project"))
  end

  def assert_specific_container_build_pod
    @container_build_pod = ContainerBuildPod.find_by(:name => "python-project-1")
    expect(@container_build_pod).to have_attributes(
      :name                          => "python-project-1",
      :phase                         => "Complete",
      :reason                        => nil,
      :output_docker_image_reference => "172.30.190.81:5000/python-project/python-project:latest",
    )

    expect(@container_build_pod.container_build).to eq(
      ContainerBuild.find_by(:name => "python-project")
    )
  end

  def assert_specific_container_template
    @container_template = ContainerTemplate.find_by(:name => "hawkular-cassandra-node-emptydir")
    expect(@container_template).to have_attributes(
      :name             => "hawkular-cassandra-node-emptydir",
      :resource_version => "871"
    )

    expect(@container_template.ext_management_system).to eq(@ems)
    expect(@container_template.container_project).to eq(ContainerProject.find_by(:name => "openshift-infra"))
    expect(@container_template.container_template_parameters.count).to eq(4)
    expect(@container_template.container_template_parameters.last).to have_attributes(
      :name => "NODE"
    )
  end

  def assert_specific_container_image
    @container_image = ContainerImage.find_by(:name => "openshift/nodejs-010-centos7")

    expect(@container_image.ext_management_system).to eq(@ems)
    expect(@container_image.environment_variables.count).to eq(10)
    expect(@container_image.labels.count).to eq(1)
    expect(@container_image.docker_labels.count).to eq(15)
  end

  def assert_container_node_with_no_hawk_attributes
    containernode = ContainerNode.first
    expect(containernode.custom_attributes.count).to eq(5)
    expect(CustomAttribute.find_by(:name => "test_attr")).to be nil
  end
end
