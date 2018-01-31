require_relative '../helpers/spec_mocked_data'
require_relative '../helpers/spec_parsed_data'
require_relative 'test_containers_persister'
require_relative 'targeted_refresh_spec_helper'

describe ManagerRefresh::Inventory::Persister do
  include SpecMockedData
  include SpecParsedData
  include TargetedRefreshSpecHelper

  ######################################################################################################################
  # Spec scenarios for making sure the skeletal pre-create passes
  ######################################################################################################################
  #

  # TODO(lsmola) we have to make this pass for :complete => true but also for :targeted => true, targeted needs
  # conditions here https://github.com/Ladas/manageiq/blob/0b7ceab23388a19c5da8672b2e8baaef8baf8a80/app/models/manager_refresh/inventory_collection.rb#L531
  [
    {:ems_refresh => {:kubernetes => {:inventory_collections => {:saver_strategy => :concurrent_safe_batch}}}}
  ].each do |settings|
    context "with settings #{settings}" do
      before :each do
        @zone = FactoryGirl.create(:zone)
        @ems  = FactoryGirl.create(:ems_kubernetes,
                                   :zone => @zone,)
        stub_settings_merge(settings)
      end

      let(:persister) { create_containers_persister }

      it "tests container relations are pre-created and updated by other refresh" do
        persister.containers.build(
          container_data(
            1,
            :container_group => persister.container_groups.lazy_find("container_group_ems_ref_1"),
            :container_image => persister.container_images.lazy_find("container_image_image_ref_1"),
          )
        )

        persister.persist!

        # Assert container_group and container_image are pre-created using the lazy_find data
        assert_containers_counts(
          :container       => 1,
          :container_group => 1,
          :container_image => 1,
        )

        container = Container.first
        expect(container).to(
          have_attributes(
            :name    => "container_name_1",
            :ems_id  => @ems.id,
            :ems_ref => "container_ems_ref_1",
          )
        )

        expect(container.container_group).to(
          have_attributes(
            :name    => nil,
            :ems_id  => @ems.id,
            :ems_ref => "container_group_ems_ref_1",
          )
        )

        expect(container.container_image).to(
          have_attributes(
            :name      => nil,
            :ems_id    => @ems.id,
            :image_ref => "container_image_image_ref_1",
          )
        )

        expect(container.container_image.container_image_registry).to be_nil

        # Now we persist the relations which should update the skeletal pre-created objects
        persister = create_containers_persister

        persister.container_images.build(
          container_image_data(
            1,
            :container_image_registry => persister.container_image_registries.lazy_find(
              :host => "container_image_registry_host_1",
              :port => "container_image_registry_name_1"
            )
          )
        )

        persister.container_groups.build(container_group_data(1))

        persister.persist!

        # Assert container_group and container_image are updated
        assert_containers_counts(
          :container                => 1,
          :container_group          => 1,
          :container_image          => 1,
          :container_image_registry => 1,
        )

        container = Container.first
        expect(container).to(
          have_attributes(
            :name    => "container_name_1",
            :ems_id  => @ems.id,
            :ems_ref => "container_ems_ref_1",
          )
        )

        expect(container.container_group).to(
          have_attributes(
            :name    => "container_group_name_1",
            :ems_id  => @ems.id,
            :ems_ref => "container_group_ems_ref_1",
          )
        )

        expect(container.container_image).to(
          have_attributes(
            :name      => "container_image_name_1",
            :ems_id    => @ems.id,
            :image_ref => "container_image_image_ref_1",
          )
        )

        expect(container.container_image.container_image_registry).to(
          have_attributes(
            :name => nil,
            :host => "container_image_registry_host_1",
            :port => "container_image_registry_name_1",
          )
        )
      end

      it "tests relations are pre-created but batch strategy doesn't mix full and skeletal records together" do
        FactoryGirl.create(:container_project, container_project_data(1).merge(:ems_id => @ems.id))
        FactoryGirl.create(:container_project, container_project_data(2).merge(:ems_id => @ems.id))

        persister.container_groups.build(
          container_group_data(
            1,
            :container_project => persister.container_projects.lazy_find("container_project_ems_ref_1"),
          )
        )
        persister.container_projects.build(container_project_data(2))

        persister.persist!

        # Assert container_group and container_image are pre-created using the lazy_find data
        assert_containers_counts(
          :container_group   => 1,
          :container_project => 2,
        )

        # The batch saving must not save full record and skeletal record together, otherwise that would
        # lead to nullifying of all attributes of the existing record, that skeletal record points to.
        expect(ContainerProject.find_by(:ems_ref => "container_project_ems_ref_1")).to(
          have_attributes(
            :name => "container_project_name_1", # This has to be "container_project_name_1",
            :ems_id  => @ems.id,
            :ems_ref => "container_project_ems_ref_1",
          )
        )
        expect(ContainerProject.find_by(:ems_ref => "container_project_ems_ref_2")).to(
          have_attributes(
            :name    => "container_project_name_2",
            :ems_id  => @ems.id,
            :ems_ref => "container_project_ems_ref_2",
          )
        )
      end

      it "test skeletal precreate sets a base STI type and entity full refresh updates it, then skeletal leaves it be" do
        # TODO(lsmola) we need to allow STI type to be updatable

      end

      it "we prec-create object that was already disconnected and the relation is filled but not reconnected" do
        FactoryGirl.create(:container_project, container_project_data(1).merge(
          :ems_id     => @ems.id,
          :deleted_on => Time.now.utc)
        )

        lazy_find_container_project = persister.container_projects.lazy_find("container_project_ems_ref_1")

        persister.container_groups.build(
          container_group_data(
            1,
            :container_project => lazy_find_container_project,
          )
        )

        persister.persist!

        assert_containers_counts(
          :container_group   => 1,
          :container_project => 1,
        )

        container_group = ContainerGroup.first
        expect(container_group).to(
          have_attributes(
            :name    => "container_group_name_1",
            :ems_ref => "container_group_ems_ref_1"
          )
        )

        expect(container_group.container_project).to(
          have_attributes(
            :name    => "container_project_name_1",
            :ems_ref => "container_project_ems_ref_1",
          )
        )
        expect(container_group.container_project).not_to be_nil
      end

      it "lazy_find with secondary ref doesn't pre-create records" do
        lazy_find_container_project = persister.container_projects.lazy_find("container_project_name_1", :ref => :by_name)
        lazy_find_container_node    = persister.container_projects.lazy_find("container_node_name_1", :ref => :by_name)

        persister.container_groups.build(
          container_group_data(
            1,
            :container_project    => lazy_find_container_project,
            :container_node       => lazy_find_container_node,
            :container_replicator => persister.container_replicators.lazy_find(
              {
                :container_project => lazy_find_container_project,
                :name              => "container_replicator_name_1"
              }, {
                :ref => :by_container_project_and_name
              }
            ),
          )
        )

        persister.persist!

        assert_containers_counts(
          :container_group => 1,
        )

        container_group = ContainerGroup.first
        expect(container_group).to(
          have_attributes(
            :name    => "container_group_name_1",
            :ems_id  => @ems.id,
            :ems_ref => "container_group_ems_ref_1",
          )
        )

        expect(container_group.container_project).to be_nil
        expect(container_group.container_node).to be_nil
        expect(container_group.container_replicator).to be_nil
      end

      it "lazy_find with secondary ref doesn't pre-create records but finds them in DB" do
        container_project = FactoryGirl.create(:container_project, container_project_data(1).merge(:ems_id => @ems.id))
        FactoryGirl.create(:container_node, container_node_data(1).merge(:ems_id => @ems.id))
        FactoryGirl.create(:container_replicator, container_replicator_data(1).merge(
          :ems_id            => @ems.id,
          :container_project => container_project)
        )
        # TODO(lsmola) we miss VCR data for this
        # FactoryGirl.create(:container_build_pod, container_build_pod_data(1).merge(:ems_id => @ems.id))

        lazy_find_container_project = persister.container_projects.lazy_find("container_project_name_1", :ref => :by_name)
        lazy_find_container_node    = persister.container_nodes.lazy_find("container_node_name_1", :ref => :by_name)

        persister.container_groups.build(
          container_group_data(
            1,
            :container_project    => lazy_find_container_project,
            :container_node       => lazy_find_container_node,
            :container_replicator => persister.container_replicators.lazy_find(
              {
                :container_project => lazy_find_container_project,
                :name              => "container_replicator_name_1"
              }, {
                :ref => :by_container_project_and_name
              }
            ),
            :container_build_pod  => persister.container_build_pods.lazy_find(
              :namespace => "container_project_name_1",
              :name      => nil
            )
          )
        )

        persister.persist!

        assert_containers_counts(
          :computer_system      => 1,
          :container_group      => 1,
          :container_project    => 1,
          :container_node       => 1,
          :container_replicator => 1,
        )

        container_group = ContainerGroup.first
        expect(container_group.container_project).to(
          have_attributes(
            :name    => "container_project_name_1",
            :ems_ref => "container_project_ems_ref_1"
          )
        )
        expect(container_group.container_node).to(
          have_attributes(
            :name    => "container_node_name_1",
            :ems_ref => "container_node_ems_ref_1"
          )
        )
        expect(container_group.container_replicator).to(
          have_attributes(
            :name    => "container_replicator_name_1",
            :ems_ref => "container_replicator_ems_ref_1"
          )
        )
        expect(container_group.container_build_pod).to be_nil
      end

      it "lazy_find with secondary ref doesn't pre-create records but finds them in DB, even when disconnected" do
        # TODO(lsmola) we can't find disconnected records using secondary ref now, we should, right?
        FactoryGirl.create(:container_project, container_project_data(1).merge(:ems_id => @ems.id, :deleted_on => Time.now.utc))
        FactoryGirl.create(:container_node, container_node_data(1).merge(:ems_id => @ems.id, :deleted_on => Time.now.utc))

        lazy_find_container_project = persister.container_projects.lazy_find("container_project_name_1", :ref => :by_name)
        lazy_find_container_node    = persister.container_projects.lazy_find("container_node_name_1", :ref => :by_name)

        persister.container_groups.build(
          container_group_data(
            1,
            :container_project => lazy_find_container_project,
            :container_node    => lazy_find_container_node,
          )
        )

        persister.persist!

        assert_containers_counts(
          :computer_system   => 1,
          :container_group   => 1,
          :container_project => 1,
          :container_node    => 1,
        )

        container_group = ContainerGroup.first
        # This project is in the DB but disconnected, we want to find it
        expect(container_group.container_project).to be_nil
        expect(container_group.container_node).to be_nil
      end

      it "we reconnect existing container group and reconnect relation by skeletal precreate" do
        # TODO(lsmola) to reconnect correctly, we need :deleted_on => nil, in :builder_params, is that viable? We probably
        # do not want to solve this in general? If yes, we would have to allow this to be settable in parser. E.g.
        # for OpenShift pods watch targeted refresh, we can refresh already disconnected entity
        FactoryGirl.create(:container_group, container_group_data(1).merge(
          :ems_id     => @ems.id,
          :deleted_on => Time.now.utc)
        )
        FactoryGirl.create(:container_project, container_project_data(1).merge(
          :ems_id     => @ems.id,
          :deleted_on => Time.now.utc)
        )

        lazy_find_container_project = persister.container_projects.lazy_find("container_project_ems_ref_1")

        persister.container_groups.build(
          container_group_data(
            1,
            :container_project => lazy_find_container_project,
          )
        )

        persister.persist!

        assert_containers_counts(
          :container_group   => 1,
          :container_project => 1,
        )

        container_group = ContainerGroup.first
        expect(container_group).to(
          have_attributes(
            :name       => "container_group_name_1",
            :ems_ref    => "container_group_ems_ref_1",
            :deleted_on => nil
          )
        )

        expect(container_group.container_project).to(
          have_attributes(
            :name    => "container_project_name_1",
            :ems_ref => "container_project_ems_ref_1",
          )
        )
        expect(container_group.container_project).not_to be_nil
      end

      it "pre-create doesn't shadow local db strategy" do
        FactoryGirl.create(:container_project, container_project_data(1).merge(:ems_id => @ems.id))

        lazy_find_container_project = persister.container_projects.lazy_find("container_project_ems_ref_1")

        persister.container_groups.build(
          container_group_data(
            1,
            :container_project => lazy_find_container_project,
            # This will go from skeletal precreate that fetches it from the DB
            :name => persister.container_projects.lazy_find("container_project_ems_ref_1", :key => :name)
          )
        )

        persister.persist!

        assert_containers_counts(
          :container_group   => 1,
          :container_project => 1,
        )

        container_group = ContainerGroup.first
        expect(container_group).to(
          have_attributes(
            :name    => "container_project_name_1",
            :ems_ref => "container_group_ems_ref_1"
          )
        )

        expect(container_group.container_project).to(
          have_attributes(
            :name    => "container_project_name_1",
            :ems_ref => "container_project_ems_ref_1"
          )
        )
      end

      it "lazy_find doesn't pre-create records if 1 of the keys is nil" do
        # TODO(lsmola) we should figure out how to safely do that, while avoiding creating bad records, we would have to
        # only call lazy_find with valid combination, which we do not do now.

        persister.container_groups.build(
          container_group_data(
            1,
            :container_build_pod => persister.container_build_pods.lazy_find(
              :namespace => "container_project_name_1",
              :name      => nil
            )
          )
        )

        persister.persist!

        assert_containers_counts(
          :container_group => 1,
        )
      end

      it "lazy_find doesn't pre-create records if :key accessor is used" do
        # TODO(lsmola) right now the :key is not even allowed in lazy_find, once it will be, the skeletal pre-create
        # should not create these
        expect do
          persister.container_groups.build(
            container_group_data(
              1,
              :container_build_pod => persister.container_build_pods.lazy_find(
                :namespace => persister.container_projects.lazy_find("container_project_name_1", :ref => :by_name, :key => :name),
                :name      => "container_build_pod_name_1"
              )
            )
          )

          persister.persist!

          assert_containers_counts(
            :container_group => 1,
          )
        end.to(raise_error("A lazy_find with a :key can't be a part of the manager_uuid"))
      end
    end
  end
end
