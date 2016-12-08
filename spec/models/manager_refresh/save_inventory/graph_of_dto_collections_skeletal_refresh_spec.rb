require_relative 'spec_helper'
require_relative 'spec_parsed_data'

describe ManagerRefresh::SaveInventory do
  include SpecHelper
  include SpecParsedData

  ######################################################################################################################
  #
  # Spec scenarios showing saving of the inventory with Skeletal refresh strategy
  #
  ######################################################################################################################
  #
  # Test all settings for ManagerRefresh::SaveInventory
  [{:dto_saving_strategy => nil},
   {:dto_saving_strategy => :recursive},
  ].each do |dto_settings|
    context "with settings #{dto_settings}" do
      before :each do
        @zone = FactoryGirl.create(:zone)
        @ems  = FactoryGirl.create(:ems_cloud, :zone => @zone)

        allow(@ems.class).to receive(:ems_type).and_return(:mock)
        allow(Settings.ems_refresh).to receive(:mock).and_return(dto_settings)
      end

      it "refreshing all records and data collects everything" do
        # Get the relations
        initialize_dto_collections
        initialize_dto_collection_data

        # Invoke the DtoCollections saving
        ManagerRefresh::SaveInventory.save_inventory(@ems, @data)

        # Assert all data were filled
        assert_everything_is_collected
      end

      it "first phase of skeletal create records only with fixed attributes and relations" do
        # Get the data
        initialize_dto_collections(:only_attributes => :relations)
        initialize_dto_collection_data

        # Invoke the DtoCollections saving
        ManagerRefresh::SaveInventory.save_inventory(@ems, @data)

        # Assert only relations and fixed attributes were filled
        assert_relations

        assert_all_records_match_hashes(
          [OrchestrationStack.all, @ems.orchestration_stacks],
          {
            :ems_ref       => "stack_ems_ref_0_1",
            :name          => "stack_name_0_1",
            :description   => nil,
            :status        => nil,
            :status_reason => nil
          }, {
            :ems_ref       => "stack_ems_ref_1_11",
            :name          => "stack_name_1_11",
            :description   => nil,
            :status        => nil,
            :status_reason => nil
          }, {
            :ems_ref       => "stack_ems_ref_1_12",
            :name          => "stack_name_1_12",
            :description   => nil,
            :status        => nil,
            :status_reason => nil
          }
        )

        assert_all_records_match_hashes(
          [OrchestrationStackResource.all, @ems.orchestration_stacks_resources],
          {
            :ems_ref           => "stack_ems_ref_1_11",
            :name              => "stack_resource_name_1_11",
            :logical_resource  => nil,
            :physical_resource => nil,
          }, {
            :ems_ref           => "stack_ems_ref_1_12",
            :name              => "stack_resource_name_1_12",
            :logical_resource  => nil,
            :physical_resource => nil,
          }
        )

        assert_all_records_match_hashes(
          [Vm.all, @ems.vms],
          {
            :ems_ref         => "vm_ems_ref_1",
            :name            => "vm_name_1",
            :location        => "vm_location_1",
            :uid_ems         => nil,
            :vendor          => "amazon",
            :raw_power_state => nil,
          }, {
            :ems_ref         => "vm_ems_ref_2",
            :name            => "vm_name_2",
            :location        => "vm_location_2",
            :uid_ems         => nil,
            :vendor          => "amazon",
            :raw_power_state => nil,
          })

        assert_all_records_match_hashes(
          [Hardware.all, @ems.hardwares],
          {
            :vm_or_template_id   => @vm1.id,
            :bitness             => nil,
            :virtualization_type => nil,
            :guest_os            => nil,
          }, {
            :vm_or_template_id   => @vm2.id,
            :bitness             => nil,
            :virtualization_type => nil,
            :guest_os            => nil,
          }, {
            :vm_or_template_id   => @miq_template1.id,
            :bitness             => nil,
            :virtualization_type => nil,
            :guest_os            => nil,
          }, {
            :vm_or_template_id   => @miq_template2.id,
            :bitness             => nil,
            :virtualization_type => nil,
            :guest_os            => nil,
          })

        assert_all_records_match_hashes(
          [Disk.all, @ems.disks],
          {
            :hardware_id => @vm1.hardware.id,
            :device_name => "disk_name_1",
            :device_type => nil,
          }, {
            :hardware_id => @vm1.hardware.id,
            :device_name => "disk_name_12",
            :device_type => nil,
          }, {
            :hardware_id => @vm1.hardware.id,
            :device_name => "disk_name_13",
            :device_type => nil,
          }, {
            :hardware_id => @vm2.hardware.id,
            :device_name => "disk_name_2",
            :device_type => nil,
          })

        assert_all_records_match_hashes(
          [ManageIQ::Providers::CloudManager::AuthKeyPair.all, @ems.key_pairs],
          {
            :name   => "key_pair_name_1",
            :status => nil,
          }, {
            :name   => "key_pair_name_2",
            :status => nil,
          }, {
            :name   => "key_pair_name_21",
            :status => nil,
          })
      end

      it "second phase of skeletal does not create any records" do
        # Get the data
        initialize_dto_collections(:only_attributes => :data)
        initialize_dto_collection_data

        # Invoke the DtoCollections saving
        ManagerRefresh::SaveInventory.save_inventory(@ems, @data)

        expect(OrchestrationStack.all).to match_array(nil)
        expect(@ems.orchestration_stacks).to match_array(nil)

        expect(OrchestrationStackResource.all).to match_array(nil)
        expect(@ems.orchestration_stacks_resources).to match_array(nil)

        expect(Vm.all).to match_array(nil)
        expect(@ems.vms).to match_array(nil)

        expect(Hardware.all).to match_array(nil)
        expect(@ems.hardwares).to match_array(nil)

        expect(Disk.all).to match_array(nil)
        expect(@ems.disks).to match_array(nil)

        expect(ManageIQ::Providers::CloudManager::AuthKeyPair.all).to match_array(nil)
        expect(@ems.key_pairs).to match_array(nil)
      end

      it "first and second phase of skeletal collects everything" do
        # Get the relations
        initialize_dto_collections(:only_attributes => :relations)
        initialize_dto_collection_data

        # Invoke the DtoCollections saving
        ManagerRefresh::SaveInventory.save_inventory(@ems, @data)

        # Get the data
        initialize_dto_collections(:only_attributes => :data)
        initialize_dto_collection_data

        # Invoke the DtoCollections saving
        ManagerRefresh::SaveInventory.save_inventory(@ems, @data)

        # Assert all data are collected
        assert_everything_is_collected
      end

      it "first and second phase, done in steps, collects partial data" do
        # Get the relations
        initialize_dto_collections(:only_attributes => :relations)
        initialize_dto_collection_data

        # Invoke the DtoCollections saving
        ManagerRefresh::SaveInventory.save_inventory(@ems, @data)

        # In second phase, lets update only few Stacks with full data, the rest must remain unchanged
        # Initialize the DtoCollections
        @data                          = {}
        @data[:orchestration_stacks]   = ::ManagerRefresh::DtoCollection.new(
          *orchestration_stacks_init_data(:only_attributes => :data))

        # Initialize the DtoCollections data
        @orchestration_stack_data_1_11 = orchestration_stack_data("1_11").merge(
          :parent => nil
        )
        @orchestration_stack_data_1_12 = orchestration_stack_data("1_12").merge(
          :parent => nil
        )

        # Fill DtoCollections with data
        add_data_to_dto_collection(@data[:orchestration_stacks],
                                   @orchestration_stack_data_1_11,
                                   @orchestration_stack_data_1_12)

        # Invoke the DtoCollections saving
        ManagerRefresh::SaveInventory.save_inventory(@ems, @data)
        assert_relations

        assert_all_records_match_hashes(
          [OrchestrationStack.all, @ems.orchestration_stacks],
          {
            :ems_ref       => "stack_ems_ref_0_1",
            :name          => "stack_name_0_1",
            :description   => nil,
            :status        => nil,
            :status_reason => nil,
          }, {
            :ems_ref       => "stack_ems_ref_1_11",
            :name          => "stack_name_1_11",
            :description   => "stack_description_1_11",
            :status        => "stack_status_1_11",
            :status_reason => "stack_status_reason_1_11",
          }, {
            :ems_ref       => "stack_ems_ref_1_12",
            :name          => "stack_name_1_12",
            :description   => "stack_description_1_12",
            :status        => "stack_status_1_12",
            :status_reason => "stack_status_reason_1_12",
          }
        )

        assert_all_records_match_hashes(
          [OrchestrationStackResource.all, @ems.orchestration_stacks_resources],
          {
            :ems_ref           => "stack_ems_ref_1_11",
            :name              => "stack_resource_name_1_11",
            :logical_resource  => nil,
            :physical_resource => nil,
          }, {
            :ems_ref           => "stack_ems_ref_1_12",
            :name              => "stack_resource_name_1_12",
            :logical_resource  => nil,
            :physical_resource => nil,
          }
        )

        assert_all_records_match_hashes(
          [Vm.all, @ems.vms],
          {
            :ems_ref         => "vm_ems_ref_1",
            :name            => "vm_name_1",
            :location        => "vm_location_1",
            :uid_ems         => nil,
            :vendor          => "amazon",
            :raw_power_state => nil,
          }, {
            :ems_ref         => "vm_ems_ref_2",
            :name            => "vm_name_2",
            :location        => "vm_location_2",
            :uid_ems         => nil,
            :vendor          => "amazon",
            :raw_power_state => nil,
          })

        assert_all_records_match_hashes(
          [Hardware.all, @ems.hardwares],
          {
            :vm_or_template_id   => @vm1.id,
            :bitness             => nil,
            :virtualization_type => nil,
            :guest_os            => nil,
          }, {
            :vm_or_template_id   => @vm2.id,
            :bitness             => nil,
            :virtualization_type => nil,
            :guest_os            => nil,
          }, {
            :vm_or_template_id   => @miq_template1.id,
            :bitness             => nil,
            :virtualization_type => nil,
            :guest_os            => nil,
          }, {
            :vm_or_template_id   => @miq_template2.id,
            :bitness             => nil,
            :virtualization_type => nil,
            :guest_os            => nil,
          })

        assert_all_records_match_hashes(
          [Disk.all, @ems.disks],
          {
            :hardware_id => @vm1.hardware.id,
            :device_name => "disk_name_1",
            :device_type => nil,
          }, {
            :hardware_id => @vm1.hardware.id,
            :device_name => "disk_name_12",
            :device_type => nil,
          }, {
            :hardware_id => @vm1.hardware.id,
            :device_name => "disk_name_13",
            :device_type => nil,
          }, {
            :hardware_id => @vm2.hardware.id,
            :device_name => "disk_name_2",
            :device_type => nil,
          })

        assert_all_records_match_hashes(
          [ManageIQ::Providers::CloudManager::AuthKeyPair.all, @ems.key_pairs],
          {
            :name   => "key_pair_name_1",
            :status => nil,
          }, {
            :name   => "key_pair_name_2",
            :status => nil,
          }, {
            :name   => "key_pair_name_21",
            :status => nil,
          })
      end
    end
  end

  def assert_relations
    @orchestration_stack_0_1  = OrchestrationStack.find_by(:ems_ref => "stack_ems_ref_0_1")
    @orchestration_stack_1_11 = OrchestrationStack.find_by(:ems_ref => "stack_ems_ref_1_11")
    @orchestration_stack_1_12 = OrchestrationStack.find_by(:ems_ref => "stack_ems_ref_1_12")

    @orchestration_stack_resource_1_11 = OrchestrationStackResource.find_by(:ems_ref => "stack_ems_ref_1_11")
    @orchestration_stack_resource_1_12 = OrchestrationStackResource.find_by(:ems_ref => "stack_ems_ref_1_12")

    @vm1 = Vm.find_by(:ems_ref => "vm_ems_ref_1")
    @vm2 = Vm.find_by(:ems_ref => "vm_ems_ref_2")

    @miq_template1 = MiqTemplate.find_by(:ems_ref => "image_ems_ref_1")
    @miq_template2 = MiqTemplate.find_by(:ems_ref => "image_ems_ref_2")

    @hardware1 = Hardware.find_by(:vm_or_template => @vm1)
    @hardware2 = Hardware.find_by(:vm_or_template => @vm2)
    @hardware3 = Hardware.find_by(:vm_or_template => @miq_template1)
    @hardware4 = Hardware.find_by(:vm_or_template => @miq_template2)

    @key_pair1  = ManageIQ::Providers::CloudManager::AuthKeyPair.find_by(:name => "key_pair_name_1")
    @key_pair2  = ManageIQ::Providers::CloudManager::AuthKeyPair.find_by(:name => "key_pair_name_2")
    @key_pair21 = ManageIQ::Providers::CloudManager::AuthKeyPair.find_by(:name => "key_pair_name_21")

    @disk1  = Disk.find_by(:hardware => @hardware1, :device_name => "disk_name_1")
    @disk12 = Disk.find_by(:hardware => @hardware1, :device_name => "disk_name_12")
    @disk13 = Disk.find_by(:hardware => @hardware1, :device_name => "disk_name_13")
    @disk2  = Disk.find_by(:hardware => @hardware2, :device_name => "disk_name_2")

    expect(@orchestration_stack_0_1.resources).to match_array([@orchestration_stack_resource_1_11,
                                                               @orchestration_stack_resource_1_12])
    expect(@orchestration_stack_1_11.resources).to match_array(nil)
    expect(@orchestration_stack_1_12.resources).to match_array(nil)

    expect(@orchestration_stack_resource_1_11.stack).to eq(@orchestration_stack_0_1)
    expect(@orchestration_stack_resource_1_12.stack).to eq(@orchestration_stack_0_1)

    expect(@orchestration_stack_0_1.parent).to eq(nil)
    expect(@orchestration_stack_1_11.parent).to eq(@orchestration_stack_0_1)
    expect(@orchestration_stack_1_12.parent).to eq(@orchestration_stack_0_1)

    expect(@vm1.genealogy_parent.id).to eq(@miq_template1.id)
    expect(@vm2.genealogy_parent.id).to eq(@miq_template2.id)

    expect(@vm1.hardware.id).to eq(@hardware1.id)
    expect(@vm2.hardware.id).to eq(@hardware2.id)
    expect(@miq_template1.hardware.id).to eq(@hardware3.id)
    expect(@miq_template2.hardware.id).to eq(@hardware4.id)

    expect(@vm1.hardware.disks.pluck(:id)).to match_array([@disk1.id, @disk12.id, @disk13.id])
    expect(@vm2.hardware.disks.pluck(:id)).to match_array([@disk2.id])

    expect(@vm1.key_pairs.pluck(:id)).to match_array([@key_pair1.id])
    expect(@vm2.key_pairs.pluck(:id)).to match_array([@key_pair2.id, @key_pair21.id])
  end

  def assert_everything_is_collected
    assert_relations

    assert_all_records_match_hashes(
      [OrchestrationStack.all, @ems.orchestration_stacks],
      {
        :ems_ref       => "stack_ems_ref_0_1",
        :name          => "stack_name_0_1",
        :description   => "stack_description_0_1",
        :status        => "stack_status_0_1",
        :status_reason => "stack_status_reason_0_1",
      }, {
        :ems_ref       => "stack_ems_ref_1_11",
        :name          => "stack_name_1_11",
        :description   => "stack_description_1_11",
        :status        => "stack_status_1_11",
        :status_reason => "stack_status_reason_1_11",
      }, {
        :ems_ref       => "stack_ems_ref_1_12",
        :name          => "stack_name_1_12",
        :description   => "stack_description_1_12",
        :status        => "stack_status_1_12",
        :status_reason => "stack_status_reason_1_12",
      }
    )

    assert_all_records_match_hashes(
      [OrchestrationStackResource.all, @ems.orchestration_stacks_resources],
      {
        :ems_ref           => "stack_ems_ref_1_11",
        :name              => "stack_resource_name_1_11",
        :logical_resource  => "stack_resource_logical_resource_1_11",
        :physical_resource => "stack_resource_physical_resource_1_11",
      }, {
        :ems_ref           => "stack_ems_ref_1_12",
        :name              => "stack_resource_name_1_12",
        :logical_resource  => "stack_resource_logical_resource_1_12",
        :physical_resource => "stack_resource_physical_resource_1_12",
      }
    )

    assert_all_records_match_hashes(
      [Vm.all, @ems.vms],
      {
        :ems_ref         => "vm_ems_ref_1",
        :name            => "vm_name_1",
        :location        => "vm_location_1",
        :uid_ems         => "vm_uid_ems_1",
        :vendor          => "amazon",
        :raw_power_state => "unknown",
      }, {
        :ems_ref         => "vm_ems_ref_2",
        :name            => "vm_name_2",
        :location        => "vm_location_2",
        :uid_ems         => "vm_uid_ems_2",
        :vendor          => "amazon",
        :raw_power_state => "unknown",
      })

    assert_all_records_match_hashes(
      [Hardware.all, @ems.hardwares],
      {
        :vm_or_template_id   => @vm1.id,
        :bitness             => 64,
        :virtualization_type => "virtualization_type_1",
        :guest_os            => "linux_generic_1",
      }, {
        :vm_or_template_id   => @vm2.id,
        :bitness             => 64,
        :virtualization_type => "virtualization_type_2",
        :guest_os            => "linux_generic_2",
      }, {
        :vm_or_template_id   => @miq_template1.id,
        :bitness             => nil,
        :virtualization_type => nil,
        :guest_os            => "linux_generic_1",
      }, {
        :vm_or_template_id   => @miq_template2.id,
        :bitness             => nil,
        :virtualization_type => nil,
        :guest_os            => "linux_generic_2",
      })

    assert_all_records_match_hashes(
      [Disk.all, @ems.disks],
      {
        :hardware_id => @vm1.hardware.id,
        :device_name => "disk_name_1",
        :device_type => "disk",
      }, {
        :hardware_id => @vm1.hardware.id,
        :device_name => "disk_name_12",
        :device_type => "disk",
      }, {
        :hardware_id => @vm1.hardware.id,
        :device_name => "disk_name_13",
        :device_type => "disk",
      }, {
        :hardware_id => @vm2.hardware.id,
        :device_name => "disk_name_2",
        :device_type => "disk",
      })

    assert_all_records_match_hashes(
      [ManageIQ::Providers::CloudManager::AuthKeyPair.all, @ems.key_pairs],
      {
        :name   => "key_pair_name_1",
        :status => "status_1",
      }, {
        :name   => "key_pair_name_2",
        :status => "status_2",
      }, {
        :name   => "key_pair_name_21",
        :status => "status_21",
      })
  end

  def initialize_dto_collections(only_attributes: nil)
    # Initialize the DtoCollections
    @data                                  = {}
    @data[:orchestration_stacks]           = ::ManagerRefresh::DtoCollection.new(
      *orchestration_stacks_init_data(:only_attributes => only_attributes))
    @data[:orchestration_stacks_resources] = ::ManagerRefresh::DtoCollection.new(
      *orchestration_stacks_resources_init_data(:only_attributes => only_attributes))
    @data[:vms]                            = ::ManagerRefresh::DtoCollection.new(
      *vms_init_data(:only_attributes => only_attributes))
    @data[:miq_templates]                  = ::ManagerRefresh::DtoCollection.new(
      *miq_templates_init_data(:only_attributes => only_attributes))
    @data[:key_pairs]                      = ::ManagerRefresh::DtoCollection.new(
      *key_pairs_init_data(:only_attributes => only_attributes))
    @data[:hardwares]                      = ::ManagerRefresh::DtoCollection.new(
      *hardwares_init_data(:only_attributes => only_attributes))
    @data[:disks]                          = ::ManagerRefresh::DtoCollection.new(
      *disks_init_data(:only_attributes => only_attributes))
  end

  def orchestration_stacks_init_data(only_attributes: nil)
    init_data(ManageIQ::Providers::CloudManager::OrchestrationStack,
              :orchestration_stacks,
              :extra_attrs     => [:name],
              :only_attributes => only_attributes)
  end

  def orchestration_stacks_resources_init_data(only_attributes: nil)
    init_data(OrchestrationStackResource,
              :orchestration_stacks_resources,
              :extra_attrs     => [:name],
              :only_attributes => only_attributes)
  end

  def vms_init_data(only_attributes: nil)
    init_data(ManageIQ::Providers::CloudManager::Vm,
              :vms,
              :extra_attrs     => [:name],
              :only_attributes => only_attributes)
  end

  def miq_templates_init_data(only_attributes: nil)
    init_data(ManageIQ::Providers::CloudManager::Template,
              :miq_templates,
              :extra_attrs     => [:name],
              :only_attributes => only_attributes)
  end

  def key_pairs_init_data(only_attributes: nil)
    init_data(ManageIQ::Providers::CloudManager::AuthKeyPair,
              :key_pairs,
              :manager_ref     => [:name],
              :only_attributes => only_attributes)
  end

  def hardwares_init_data(only_attributes: nil)
    init_data(Hardware,
              :hardwares,
              :manager_ref     => [:vm_or_template],
              :only_attributes => only_attributes)
  end

  def disks_init_data(only_attributes: nil)
    init_data(Disk,
              :disks,
              :manager_ref     => [:hardware, :device_name],
              :only_attributes => only_attributes)
  end

  def init_data(model_class, association, manager_ref: nil, extra_attrs: [], only_attributes: nil)
    init_data = {
      :parent      => @ems,
      :association => association
    }

    init_data[:manager_ref] = manager_ref if manager_ref

    fixed_attributes = fixed_attributes_for(model_class) + extra_attrs

    if only_attributes == :relations
      # We want to have a :type in all records
      init_data[:attributes_whitelist] = fixed_attributes + [:type]
    elsif only_attributes == :data
      init_data[:attributes_blacklist] = fixed_attributes
      init_data[:update_only]          = true
    end

    return model_class, init_data
  end

  def fixed_attributes_for(model_class)
    fixed_attributes = []
    fixed_attributes += (validation_attributes(model_class) || [])
    fixed_attributes += (association_attributes(model_class) || [])
    fixed_attributes += custom_association_attributes
    fixed_attributes
  end

  def validation_attributes(model_class)
    # All validation attributes, that are needed so we can create a record of a model
    presence_validators  = model_class.validators.detect { |x| x.kind_of? ActiveRecord::Validations::PresenceValidator }
    inclusion_validators = model_class.validators.detect { |x| x.kind_of? ActiveModel::Validations::InclusionValidator }

    validation_attributes = []
    validation_attributes += presence_validators.attributes unless presence_validators.blank?
    validation_attributes += inclusion_validators.attributes unless inclusion_validators.blank?
    validation_attributes
  end

  def association_attributes(model_class)
    # All association attributes and foreign keys of the model
    model_class.reflect_on_all_associations.map { |x| [x.name, x.foreign_key] }.flatten.compact.map(&:to_sym)
  end

  def custom_association_attributes
    # These are associations that are not modeled in a standard rails way, e.g. the ancestry
    [:parent, :genealogy_parent, :genealogy_parent_object]
  end

  def initialize_dto_collection_data
    # Initialize the DtoCollections data
    @orchestration_stack_data_0_1           = orchestration_stack_data("0_1").merge(
      # TODO(lsmola) not possible until we have an enhanced transitive edges check
      # :parent => @data[:orchestration_stacks].lazy_find(orchestration_stack_data("0_0")[:ems_ref]))
      :parent => nil)
    @orchestration_stack_data_1_11          = orchestration_stack_data("1_11").merge(
      :parent => @data[:orchestration_stacks_resources].lazy_find(orchestration_stack_data("1_11")[:ems_ref],
                                                                  :key => :stack)
    )
    @orchestration_stack_data_1_12          = orchestration_stack_data("1_12").merge(
      :parent => @data[:orchestration_stacks_resources].lazy_find(orchestration_stack_data("1_12")[:ems_ref],
                                                                  :key => :stack)
    )
    @orchestration_stack_resource_data_1_11 = orchestration_stack_resource_data("1_11").merge(
      :ems_ref => orchestration_stack_data("1_11")[:ems_ref],
      :stack   => @data[:orchestration_stacks].lazy_find(orchestration_stack_data("0_1")[:ems_ref]),
    )
    @orchestration_stack_resource_data_1_12 = orchestration_stack_resource_data("1_12").merge(
      :ems_ref => orchestration_stack_data("1_12")[:ems_ref],
      :stack   => @data[:orchestration_stacks].lazy_find(orchestration_stack_data("0_1")[:ems_ref]),
    )

    @key_pair_data_1  = key_pair_data(1)
    @key_pair_data_2  = key_pair_data(2)
    @key_pair_data_21 = key_pair_data(21)

    @image_data_1 = image_data(1)
    @image_data_2 = image_data(2)

    @image_hardware_data_1 = image_hardware_data(1).merge(
      :vm_or_template => @data[:miq_templates].lazy_find(image_data(1)[:ems_ref])
    )
    @image_hardware_data_2 = image_hardware_data(2).merge(
      :vm_or_template => @data[:miq_templates].lazy_find(image_data(2)[:ems_ref])
    )

    @vm_data_1 = vm_data(1).merge(
      :genealogy_parent => @data[:miq_templates].lazy_find(image_data(1)[:ems_ref]),
      :key_pairs        => [@data[:key_pairs].lazy_find(key_pair_data(1)[:name])],
    )
    @vm_data_2 = vm_data(2).merge(
      :genealogy_parent => @data[:miq_templates].lazy_find(image_data(2)[:ems_ref]),
      :key_pairs        => [@data[:key_pairs].lazy_find(key_pair_data(2)[:name]),
                            @data[:key_pairs].lazy_find(key_pair_data(21)[:name])],
    )

    @hardware_data_1 = hardware_data(1).merge(
      :guest_os       => @data[:hardwares].lazy_find(image_data(1)[:ems_ref], :key => :guest_os),
      :vm_or_template => @data[:vms].lazy_find(vm_data(1)[:ems_ref])
    )
    @hardware_data_2 = hardware_data(2).merge(
      :guest_os       => @data[:hardwares].lazy_find(image_data(2)[:ems_ref], :key => :guest_os),
      :vm_or_template => @data[:vms].lazy_find(vm_data(2)[:ems_ref])
    )

    @disk_data_1  = disk_data(1).merge(
      :hardware => @data[:hardwares].lazy_find(vm_data(1)[:ems_ref]),
    )
    @disk_data_12 = disk_data(12).merge(
      :hardware => @data[:hardwares].lazy_find(vm_data(1)[:ems_ref]),
    )
    @disk_data_13 = disk_data(13).merge(
      :hardware => @data[:hardwares].lazy_find(vm_data(1)[:ems_ref]),
    )
    @disk_data_2  = disk_data(2).merge(
      :hardware => @data[:hardwares].lazy_find(vm_data(2)[:ems_ref]),
    )

    # Fill DtoCollections with data
    add_data_to_dto_collection(@data[:orchestration_stacks],
                               @orchestration_stack_data_0_1,
                               @orchestration_stack_data_1_11,
                               @orchestration_stack_data_1_12)
    add_data_to_dto_collection(@data[:orchestration_stacks_resources],
                               @orchestration_stack_resource_data_1_11,
                               @orchestration_stack_resource_data_1_12)
    add_data_to_dto_collection(@data[:vms],
                               @vm_data_1,
                               @vm_data_2)
    add_data_to_dto_collection(@data[:miq_templates],
                               @image_data_1,
                               @image_data_2)
    add_data_to_dto_collection(@data[:hardwares],
                               @hardware_data_1,
                               @hardware_data_2,
                               @image_hardware_data_1,
                               @image_hardware_data_2)
    add_data_to_dto_collection(@data[:key_pairs], @key_pair_data_1, @key_pair_data_2, @key_pair_data_21)
    add_data_to_dto_collection(@data[:disks], @disk_data_1, @disk_data_12, @disk_data_13, @disk_data_2)
  end
end
