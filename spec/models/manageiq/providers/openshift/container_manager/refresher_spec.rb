describe ManageIQ::Providers::Openshift::ContainerManager::Refresher do
  let(:all_images_count) { 31 } # including /oapi/v1/images data
  let(:pod_images_count) { 4 }  # only images mentioned by pods

  before(:each) do
    allow(MiqServer).to receive(:my_zone).and_return("default")
    @ems = FactoryGirl.create(:ems_openshift, :hostname => "10.35.0.174")
  end

  it ".ems_type" do
    expect(described_class.ems_type).to eq(:openshift)
  end

  def normal_refresh
    VCR.use_cassette(described_class.name.underscore,
                     :match_requests_on => [:path,]) do # , :record => :new_episodes) do
      EmsRefresh.refresh(@ems)
    end
  end

  it "will perform a full refresh on openshift" do
    2.times do
      @ems.reload
      normal_refresh
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
      assert_specific_running_container_image
      assert_specific_unused_container_image(:metadata => true, :connected => true)
    end
  end

  context "when refreshing an empty DB" do
    # CREATING FIRST VCR
    # To recreate the tested objects in OpenShift use the template file:
    # spec/vcr_cassettes/manageiq/providers/openshift/container_manager/test_objects_template.yml
    # and the following commands for 3 projects my-project-X (X=0/1/2):
    # oc new-project my-project-X
    # oc process -f template.yml -v INDEX=X | oc create -f -

    before(:each) do
      VCR.use_cassette("#{described_class.name.underscore}_before_openshift_deletions",
                       :match_requests_on => [:path,]) do # , :record => :new_episodes) do
        EmsRefresh.refresh(@ems)
      end
    end

    it "saves the objects in the DB" do
      expect(ContainerProject.count).to eq(8)
      expect(ContainerImage.count).to eq(44)
      expect(ContainerRoute.count).to eq(6)
      expect(ContainerTemplate.count).to eq(30)
      expect(ContainerReplicator.count).to eq(10)
      expect(ContainerBuild.count).to eq(3)
      expect(ContainerBuildPod.count).to eq(3)
      expect(CustomAttribute.count).to eq(532)
      expect(ContainerTemplateParameter.count).to eq(264)
      expect(ContainerRoute.find_by(:name => "my-route-2").labels.count).to eq(1)
      expect(ContainerTemplate.find_by(:name => "my-template-2").container_template_parameters.count).to eq(1)
    end

    context "when refreshing non empty DB" do
      # CREATING SECOND VCR
      # To delete the tested objects in OpenShift use the following commands:
      # oc delete project my-project-0
      # oc project my-project-1
      # oc delete pod my-pod-1
      # oc delete service my-service-1
      # oc delete route my-route-1
      # oc delete resourceQuota my-resource-quota-1
      # oc delete limitRange my-limit-range-1
      # oc delete persistentVolumeClaim my-persistentvolumeclaim-1
      # oc delete template my-template-1
      # oc delete build my-build-1
      # oc delete buildconfig my-build-config-1
      # oc project my-project-2
      # oc label route my-route-2 key-route-label-
      # oc edit template my-template-2 # remove the template parameters from the file and save it
      # oc delete pod my-pod-2

      before(:each) do
        VCR.use_cassette("#{described_class.name.underscore}_after_openshift_deletions",
                         :match_requests_on => [:path,]) do # , :record => :new_episodes) do
          EmsRefresh.refresh(@ems)
        end
      end

      it "archives objects" do
        expect(ContainerProject.count).to eq(8)
        expect(ContainerProject.where(:deleted_on => nil).count).to eq(7)
        expect(ContainerImage.count).to eq(43) # should be 44
        expect(ContainerImage.where(:deleted_on => nil).count).to eq(43) # should be 44
      end

      it "removes the deleted objects from the DB" do
        expect(ContainerRoute.count).to eq(4)
        expect(ContainerTemplate.count).to eq(28)
        expect(ContainerReplicator.count).to eq(8)
        expect(ContainerBuild.count).to eq(1)
        expect(ContainerBuildPod.count).to eq(1)
        expect(CustomAttribute.count).to eq(523)
        expect(ContainerTemplateParameter.count).to eq(261)

        expect(ContainerTemplate.find_by(:name => "my-template-0")).to be_nil
        expect(ContainerTemplate.find_by(:name => "my-template-1")).to be_nil

        expect(ContainerRoute.find_by(:name => "my-route-0")).to be_nil
        expect(ContainerRoute.find_by(:name => "my-route-1")).to be_nil

        expect(ContainerReplicator.find_by(:name => "my-replicationcontroller-0")).to be_nil
        expect(ContainerReplicator.find_by(:name => "my-replicationcontroller-1")).to be_nil

        expect(ContainerBuildPod.find_by(:name => "my-build-0")).to be_nil
        expect(ContainerBuildPod.find_by(:name => "my-build-1")).to be_nil

        expect(ContainerBuild.find_by(:name => "my-build-config-0")).to be_nil
        expect(ContainerBuild.find_by(:name => "my-build-config-1")).to be_nil

        expect(ContainerRoute.find_by(:name => "my-route-2").labels.count).to eq(0)
        expect(ContainerTemplate.find_by(:name => "my-template-2").container_template_parameters.count).to eq(0)
      end

      it "disconnects container projects" do
        project0 = ContainerProject.find_by(:name => "my-project-0")
        project1 = ContainerProject.find_by(:name => "my-project-1")

        expect(project0).not_to be_nil
        expect(project0.deleted_on).not_to be_nil
        expect(project0.ext_management_system).to be_nil
        expect(project0.old_ems_id).to eq(@ems.id)
        expect(project0.container_groups.count).to eq(0)
        expect(project0.containers.count).to eq(0)
        expect(project0.container_definitions.count).to eq(0)

        expect(project1.container_groups.count).to eq(0)
        expect(project1.containers.count).to eq(0)
        expect(project1.container_definitions.count).to eq(0)
      end
    end
  end

  it 'will skip container_images if get_container_images = false' do
    stub_settings(Settings.to_hash.deep_merge(
      :ems_refresh => {:openshift => {:get_container_images => false}},
    ))
    VCR.use_cassette(described_class.name.underscore,
                     :match_requests_on              => [:path,],
                     :allow_unused_http_interactions => true) do # , :record => :new_episodes) do
      EmsRefresh.refresh(@ems)
    end

    @ems.reload

    expect(ContainerImage.count).to eq(pod_images_count)
    assert_specific_running_container_image
  end

  it 'will not delete previously collected metadata if get_container_images = false' do
    normal_refresh
    stub_settings(Settings.to_hash.deep_merge(
      :ems_refresh => {:openshift => {:get_container_images => false}},
    ))

    VCR.use_cassette(described_class.name.underscore,
                     :match_requests_on              => [:path,],
                     :allow_unused_http_interactions => true) do # , :record => :new_episodes) do
      EmsRefresh.refresh(@ems)
    end

    @ems.reload

    # Unused images are disconnected, metadata is retained either way.
    expect(@ems.container_images.count).to eq(pod_images_count)
    assert_specific_running_container_image
    assert_specific_unused_container_image(:metadata => true, :connected => false)
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
    expect(ContainerTemplate.count).to eq(6)
    expect(ContainerImage.count).to eq(all_images_count)
    expect(ContainerImage.joins(:containers).distinct.count).to eq(pod_images_count)
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

  def assert_specific_container_services
    @containersrv = ContainerService.find_by_name("frontend")
    expect(@containersrv).to have_attributes(
      :name             => "frontend",
      :session_affinity => "None",
      :portal_ip        => "172.30.141.69"
    )

    expect(@containersrv.container_project).to eq(ContainerProject.find_by(:name => "test"))
    expect(@containersrv.ext_management_system).to eq(@ems)
    expect(@containersrv.container_image_registry).to be_nil

    expect(ContainerService.find_by_name("docker-registry").container_image_registry.name). to eq("172.30.44.14")
  end

  def assert_specific_container_image_registry
    @registry = ContainerImageRegistry.find_by_name("172.30.44.14")
    expect(@registry).to have_attributes(
      :name => "172.30.44.14",
      :host => "172.30.44.14",
      :port => "5000"
    )
    expect(@registry.container_services.first.name).to eq("docker-registry")
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

  def assert_specific_container_template
    @container_template = ContainerTemplate.find_by_name("hawkular-cassandra-node-emptydir")
    expect(@container_template).to have_attributes(
      :name             => "hawkular-cassandra-node-emptydir",
      :resource_version => "1398"
    )

    expect(@container_template.ext_management_system).to eq(@ems)
    expect(@container_template.container_project).to eq(ContainerProject.find_by(:name => "openshift-infra"))
    expect(@container_template.container_template_parameters.count).to eq(4)
    expect(@container_template.container_template_parameters.last).to have_attributes(
      :name => "NODE"
    )
  end

  def assert_specific_unused_container_image(metadata:, connected:)
    # An image not mentioned in /pods, only in /images, built by openshift so it has metadata.
    @container_image = ContainerImage.find_by_name("centos/postgresql-95-centos7")

    expect(@container_image.ext_management_system).to eq(connected ? @ems : nil)
    expect(@container_image.environment_variables.count).to eq(metadata ? 9 : 0)
    expect(@container_image.labels.count).to eq(1)
    expect(@container_image.docker_labels.count).to eq(metadata ? 9 : 0)
  end

  def assert_specific_running_container_image
    # This VCR cassette has no overlap between images running in /pods
    # and /images from openshift registry.
    # At least test one from /pods then.
    @container_image = ContainerImage.find_by(:name => "openshift/mysql-55-centos7")

    expect(@container_image.ext_management_system).to eq(@ems)
    expect(@container_image.environment_variables.count).to eq(0)
    expect(@container_image.labels.count).to eq(0)
    expect(@container_image.docker_labels.count).to eq(0)
  end
end
