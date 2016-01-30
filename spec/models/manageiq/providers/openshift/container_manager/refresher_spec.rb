describe ManageIQ::Providers::Openshift::ContainerManager::Refresher do
  before(:each) do
    allow(MiqServer).to receive(:my_zone).and_return("default")
    @ems = FactoryGirl.create(:ems_openshift, :hostname => "10.35.0.174")
  end

  it ".ems_type" do
    expect(described_class.ems_type).to eq(:openshift)
  end

  it "will perform a full refresh on openshift" do
    2.times do
      @ems.reload
      VCR.use_cassette("#{described_class.name.underscore}",
                       :match_requests_on => [:path,]) do # , :record => :new_episodes) do
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
      assert_specific_container_build
      assert_specific_container_build_pod
    end
  end

  def assert_table_counts
    expect(ContainerGroup.count).to eq(5)
    expect(ContainerNode.count).to eq(1)
    expect(Container.count).to eq(5)
    expect(ContainerService.count).to eq(4)
    expect(ContainerPortConfig.count).to eq(4)
    expect(ContainerDefinition.count).to eq(5)
    expect(ContainerRoute.count).to eq(1)
    expect(ContainerProject.count).to eq(4)
    expect(ContainerBuild.count).to eq(1)
    expect(ContainerBuildPod.count).to eq(1)
  end

  def assert_ems
    expect(@ems).to have_attributes(
      :port => 8443,
      :type => "ManageIQ::Providers::Openshift::ContainerManager"
    )
  end

  def assert_specific_container
    @container = Container.find_by_name("ruby-helloworld-database")
    expect(@container).to have_attributes(
      :name          => "ruby-helloworld-database",
      :restart_count => 0,
    )
    expect(@container[:backing_ref]).not_to be_nil

    # Check the relation to container node
    expect(@container.container_group).to have_attributes(
      :name => "database-1-a20bt"
    )
  end

  def assert_specific_container_group
    @containergroup = ContainerGroup.find_by_name("database-1-a20bt")
    expect(@containergroup).to have_attributes(
      :name           => "database-1-a20bt",
      :restart_policy => "Always",
      :dns_policy     => "ClusterFirst",
    )

    # Check the relation to container node
    expect(@containergroup.container_node).to have_attributes(
      :name => "dhcp-0-129.tlv.redhat.com"
    )

    # Check the relation to containers
    expect(@containergroup.containers.count).to eq(1)
    expect(@containergroup.containers.last).to have_attributes(
      :name => "ruby-helloworld-database"
    )

    expect(@containergroup.container_project).to eq(ContainerProject.find_by(:name => "test"))
    expect(@containergroup.ext_management_system).to eq(@ems)
  end

  def assert_specific_container_node
    @containernode = ContainerNode.first
    expect(@containernode).to have_attributes(
      :name          => "dhcp-0-129.tlv.redhat.com",
      :lives_on_type => nil,
      :lives_on_id   => nil
    )

    expect(@containernode.ext_management_system).to eq(@ems)
  end

  def assert_specific_container_service
    @containersrv = ContainerService.find_by_name("frontend")
    expect(@containersrv).to have_attributes(
      :name             => "frontend",
      :session_affinity => "None",
      :portal_ip        => "172.30.141.69"
    )

    expect(@containersrv.container_project).to eq(ContainerProject.find_by(:name => "test"))
    expect(@containersrv.ext_management_system).to eq(@ems)
  end

  def assert_specific_container_project
    @container_pr = ContainerProject.find_by_name("test")
    expect(@container_pr).to have_attributes(
      :name         => "test",
      :display_name => ""
    )

    expect(@container_pr.container_groups.count).to eq(4)
    expect(@container_pr.container_routes.count).to eq(1)
    expect(@container_pr.container_replicators.count).to eq(2)
    expect(@container_pr.container_services.count).to eq(2)
    expect(@container_pr.ext_management_system).to eq(@ems)
  end

  def assert_specific_container_route
    @container_route = ContainerRoute.find_by_name("route-edge")
    expect(@container_route).to have_attributes(
      :name      => "route-edge",
      :host_name => "www.example.com"
    )

    expect(@container_route.container_service).to have_attributes(
      :name => "frontend"
    )

    expect(@container_route.container_project).to have_attributes(
      :name    => "test"
    )

    expect(@container_route.ext_management_system).to eq(@ems)
  end

  def assert_specific_container_build
    @container_build = ContainerBuild.find_by_name("ruby-sample-build")
    expect(@container_build).to have_attributes(
      :name              => "ruby-sample-build",
      :build_source_type => "Git",
      :source_git        => "https://github.com/openshift/ruby-hello-world.git",
      :output_name       => "origin-ruby-sample:latest",
    )

    expect(@container_build.container_project).to eq(ContainerProject.find_by(:name => "default"))
  end

  def assert_specific_container_build_pod
    @container_build_pod = ContainerBuildPod.find_by_name("ruby-sample-build-1")
    expect(@container_build_pod).to have_attributes(
      :name                          => "ruby-sample-build-1",
      :phase                         => "Failed",
      :reason                        => "ExceededRetryTimeout",
      :output_docker_image_reference => nil,
    )

    expect(@container_build_pod.container_build).to eq(
      ContainerBuild.find_by(:name => "ruby-sample-build"))
  end
end
