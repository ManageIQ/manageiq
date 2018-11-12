require "inventory_refresh"
require_relative 'helpers/spec_mocked_data'
require_relative 'helpers/spec_parsed_data'
require_relative 'test_persister'
require_relative 'targeted_refresh_spec_helper'

describe ManageIQ::Providers::Inventory::Persister do
  include SpecMockedData
  include SpecParsedData
  include TargetedRefreshSpecHelper

  ######################################################################################################################
  # Spec scenarios for making sure the local db index is able to build complex queries using references
  ######################################################################################################################
  #
  before do
    @zone = FactoryGirl.create(:zone)
    @ems  = FactoryGirl.create(:ems_cloud,
                               :zone            => @zone,
                               :network_manager => FactoryGirl.create(:ems_network, :zone => @zone))

    allow(@ems.class).to receive(:ems_type).and_return(:mock)
    allow(Settings.ems_refresh).to receive(:mock).and_return({})
  end

  before do
    initialize_mocked_records
  end

  let(:persister) { create_persister }

  context "check we can load network records from the DB" do
    it "finds in one batch after the scanning" do
      lazy_find_vm1        = persister.vms.lazy_find(:ems_ref => vm_data(1)[:ems_ref])
      lazy_find_vm2        = persister.vms.lazy_find(:ems_ref => vm_data(2)[:ems_ref])
      lazy_find_vm60       = persister.vms.lazy_find(:ems_ref => vm_data(60)[:ems_ref])
      lazy_find_hardware1  = persister.hardwares.lazy_find(:vm_or_template => lazy_find_vm1)
      lazy_find_hardware2  = persister.hardwares.lazy_find(:vm_or_template => lazy_find_vm2)
      lazy_find_hardware60 = persister.hardwares.lazy_find(:vm_or_template => lazy_find_vm60)

      lazy_find_network1 = persister.networks.lazy_find(
        {:hardware => lazy_find_hardware1, :description => "public"},
        {:key     => :hostname,
         :default => 'default_value_unknown'}
      )
      lazy_find_network2 = persister.networks.lazy_find(
        {:hardware => lazy_find_hardware2, :description => "public"},
        {:key     => :hostname,
         :default => 'default_value_unknown'}
      )
      lazy_find_network60 = persister.networks.lazy_find(
        {:hardware => lazy_find_hardware60, :description => "public"},
        {:key     => :hostname,
         :default => 'default_value_unknown'}
      )

      @vm_data101 = vm_data(101).merge(
        :flavor           => persister.flavors.lazy_find(:ems_ref => flavor_data(1)[:name]),
        :genealogy_parent => persister.miq_templates.lazy_find(:ems_ref => image_data(1)[:ems_ref]),
        :key_pairs        => [persister.key_pairs.lazy_find(:name => key_pair_data(1)[:name])],
        :location         => lazy_find_network1,
      )

      @vm_data102 = vm_data(102).merge(
        :flavor           => persister.flavors.lazy_find(:ems_ref => flavor_data(1)[:name]),
        :genealogy_parent => persister.miq_templates.lazy_find(:ems_ref => image_data(1)[:ems_ref]),
        :key_pairs        => [persister.key_pairs.lazy_find(:name => key_pair_data(1)[:name])],
        :location         => lazy_find_network2,
      )

      @vm_data160 = vm_data(160).merge(
        :flavor           => persister.flavors.lazy_find(:ems_ref => flavor_data(1)[:name]),
        :genealogy_parent => persister.miq_templates.lazy_find(:ems_ref => image_data(1)[:ems_ref]),
        :key_pairs        => [persister.key_pairs.lazy_find(:name => key_pair_data(1)[:name])],
        :location         => lazy_find_network60,
      )

      persister.vms.build(@vm_data101)
      persister.vms.build(@vm_data102)
      persister.vms.build(@vm_data160)

      InventoryRefresh::InventoryCollection::Scanner.scan!(persister.inventory_collections)

      # Assert the local db index is empty if we do not load the reference
      expect(persister.networks.index_proxy.send(:local_db_indexes)[:manager_ref].send(:index)).to be_nil

      lazy_find_network1.load

      # Assert all references are loaded at once
      expect(persister.networks.index_proxy.send(:local_db_indexes)[:manager_ref].send(:index).keys).to(
        match_array(
          [
            "vm_ems_ref_1__public",
            "vm_ems_ref_2__public"
          ]
        )
      )

      expect(lazy_find_network1.load).to eq "host_10_10_10_1.com"
      expect(lazy_find_network2.load).to eq "host_10_10_10_2.com"
      expect(lazy_find_network60.load).to eq "default_value_unknown"
    end

    it "finds one by one before we scan" do
      lazy_find_vm1        = persister.vms.lazy_find(:ems_ref => vm_data(1)[:ems_ref])
      lazy_find_vm2        = persister.vms.lazy_find(:ems_ref => vm_data(2)[:ems_ref])
      lazy_find_vm60       = persister.vms.lazy_find(:ems_ref => vm_data(60)[:ems_ref])
      lazy_find_hardware1  = persister.hardwares.lazy_find(:vm_or_template => lazy_find_vm1)
      lazy_find_hardware2  = persister.hardwares.lazy_find(:vm_or_template => lazy_find_vm2)
      lazy_find_hardware60 = persister.hardwares.lazy_find(:vm_or_template => lazy_find_vm60)
      # Assert the local db index is empty if we do not load the reference
      expect(persister.networks.index_proxy.send(:local_db_indexes)[:manager_ref].send(:index)).to be_nil

      network1 = persister.networks.lazy_find(:hardware => lazy_find_hardware1, :description => "public").load
      # Assert all references are one by one
      expect(persister.networks.index_proxy.send(:local_db_indexes)[:manager_ref].send(:index).keys).to(
        match_array(
          [
            "vm_ems_ref_1__public",
          ]
        )
      )
      network2 = persister.networks.find(:hardware => lazy_find_hardware2, :description => "public")
      expect(persister.networks.index_proxy.send(:local_db_indexes)[:manager_ref].send(:index).keys).to(
        match_array(
          [
            "vm_ems_ref_1__public",
            "vm_ems_ref_2__public"
          ]
        )
      )
      network60 = persister.networks.find(:hardware => lazy_find_hardware60, :description => "public")
      expect(persister.networks.index_proxy.send(:local_db_indexes)[:manager_ref].send(:index).keys).to(
        match_array(
          [
            "vm_ems_ref_1__public",
            "vm_ems_ref_2__public"
          ]
        )
      )

      # TODO(lsmola) known weakness, manager_uuid is wrong, but index is correct. So this doesn't affect a functionality
      # now, but it can be confusing
      expect(network1.manager_uuid).to eq "__public"
      expect(network2.manager_uuid).to eq "__public"
      expect(network60).to be_nil
    end
  end

  context "check we can load stack resource records from the DB" do
    it "finds in one batch after the scanning" do
      lazy_find_stack_1_11 = persister.orchestration_stacks.lazy_find(
        :ems_ref => orchestration_stack_data("1_11")[:ems_ref]
      )
      lazy_find_stack_1_12 = persister.orchestration_stacks.lazy_find(
        :ems_ref => orchestration_stack_data("1_12")[:ems_ref]
      )

      # Assert the local db index is empty if we do not load the reference
      expect(persister.orchestration_stacks_resources.index_proxy.send(:local_db_indexes)[:by_stack_and_ems_ref].send(:index)).to be_nil

      stack_resource_1_11_1 = persister.orchestration_stacks_resources.lazy_find(
        {
          :stack   => lazy_find_stack_1_11,
          :ems_ref => orchestration_stack_resource_data("1_11_1")[:ems_ref]
        },
        {:ref => :by_stack_and_ems_ref}
      )
      stack_resource_1_11_2 = persister.orchestration_stacks_resources.lazy_find(
        {
          :stack   => lazy_find_stack_1_11,
          :ems_ref => orchestration_stack_resource_data("1_11_2")[:ems_ref]
        },
        {:ref => :by_stack_and_ems_ref}
      )
      stack_resource_1_11_3 = persister.orchestration_stacks_resources.lazy_find(
        {
          :stack   => lazy_find_stack_1_11,
          :ems_ref => orchestration_stack_resource_data("1_11_3")[:ems_ref]
        },
        {:ref => :by_stack_and_ems_ref}
      )
      stack_1_12 = persister.orchestration_stacks_resources.lazy_find(
        {
          :stack   => lazy_find_stack_1_12,
          :ems_ref => orchestration_stack_resource_data("1_12_1")[:ems_ref]
        },
        {:ref => :by_stack_and_ems_ref,
         :key => :stack},
      )

      @network_port1 = network_port_data(1).merge(
        :device => stack_resource_1_11_1
      )
      @network_port2 = network_port_data(2).merge(
        :device => stack_resource_1_11_2
      )
      @network_port3 = network_port_data(3).merge(
        :device => stack_resource_1_11_3
      )
      @network_port4 = network_port_data(4).merge(
        :device => stack_1_12
      )

      persister.network_ports.build(@network_port1)
      persister.network_ports.build(@network_port2)
      persister.network_ports.build(@network_port3)
      persister.network_ports.build(@network_port4)

      # Save the collections, which invokes scanner
      persister.persist!

      # Loading 1 should load all scanned
      stack_resource_1_11_3.load

      expect(persister.orchestration_stacks_resources.index_proxy.send(:local_db_indexes)[:by_stack_and_ems_ref].send(:index).keys).to(
        match_array(
          [
            "stack_ems_ref_1_11__stack_resource_physical_resource_1_11_1",
            "stack_ems_ref_1_11__stack_resource_physical_resource_1_11_2",
            "stack_ems_ref_1_12__stack_resource_physical_resource_1_12_1",
          ]
        )
      )

      # Getting already loaded resource is taking it from cache
      persister.orchestration_stacks_resources.lazy_find(
        {
          :stack   => lazy_find_stack_1_11,
          :ems_ref => orchestration_stack_resource_data("1_11_3")[:ems_ref]
        },
        {:ref => :by_stack_and_ems_ref}
      ).load

      expect(persister.orchestration_stacks_resources.index_proxy.send(:local_db_indexes)[:by_stack_and_ems_ref].send(:index).keys).to(
        match_array(
          [
            "stack_ems_ref_1_11__stack_resource_physical_resource_1_11_1",
            "stack_ems_ref_1_11__stack_resource_physical_resource_1_11_2",
            "stack_ems_ref_1_12__stack_resource_physical_resource_1_12_1"
          ]
        )
      )

      expect(NetworkPort.find_by(:ems_ref => network_port_data(1)[:ems_ref]).device.ems_ref).to eq "stack_resource_physical_resource_1_11_1"
      expect(NetworkPort.find_by(:ems_ref => network_port_data(2)[:ems_ref]).device.ems_ref).to eq "stack_resource_physical_resource_1_11_2"
      expect(NetworkPort.find_by(:ems_ref => network_port_data(3)[:ems_ref]).device).to be_nil
      expect(NetworkPort.find_by(:ems_ref => network_port_data(4)[:ems_ref]).device.ems_ref).to eq "stack_ems_ref_1_12"
    end

    it "finds one by one before we scan" do
      lazy_find_stack_1_11 = persister.orchestration_stacks.lazy_find(
        :ems_ref => orchestration_stack_data("1_11")[:ems_ref]
      )
      lazy_find_stack_1_12 = persister.orchestration_stacks.lazy_find(
        :ems_ref => orchestration_stack_data("1_12")[:ems_ref]
      )

      # Assert the local db index is empty if we do not load the reference
      expect(persister.orchestration_stacks_resources.index_proxy.send(:local_db_indexes)[:by_stack_and_ems_ref].send(:index)).to be_nil

      stack_resource_1_11_1 = persister.orchestration_stacks_resources.find(
        {
          :stack   => lazy_find_stack_1_11,
          :ems_ref => orchestration_stack_resource_data("1_11_1")[:ems_ref]
        },
        {:ref => :by_stack_and_ems_ref}
      )

      # Assert all references are one by one
      expect(persister.orchestration_stacks_resources.index_proxy.send(:local_db_indexes)[:by_stack_and_ems_ref].send(:index).keys).to(
        match_array(
          [
            "stack_ems_ref_1_11__stack_resource_physical_resource_1_11_1",
          ]
        )
      )

      stack_resource_1_11_2 = persister.orchestration_stacks_resources.lazy_find(
        {
          :stack   => lazy_find_stack_1_11,
          :ems_ref => orchestration_stack_resource_data("1_11_2")[:ems_ref]
        },
        {:ref => :by_stack_and_ems_ref}
      ).load

      expect(persister.orchestration_stacks_resources.index_proxy.send(:local_db_indexes)[:by_stack_and_ems_ref].send(:index).keys).to(
        match_array(
          [
            "stack_ems_ref_1_11__stack_resource_physical_resource_1_11_1",
            "stack_ems_ref_1_11__stack_resource_physical_resource_1_11_2"
          ]
        )
      )

      stack_resource_1_11_3 = persister.orchestration_stacks_resources.lazy_find(
        {
          :stack   => lazy_find_stack_1_11,
          :ems_ref => orchestration_stack_resource_data("1_11_3")[:ems_ref]
        },
        {:ref => :by_stack_and_ems_ref}
      ).load

      expect(persister.orchestration_stacks_resources.index_proxy.send(:local_db_indexes)[:by_stack_and_ems_ref].send(:index).keys).to(
        match_array(
          [
            "stack_ems_ref_1_11__stack_resource_physical_resource_1_11_1",
            "stack_ems_ref_1_11__stack_resource_physical_resource_1_11_2"
          ]
        )
      )

      stack_1_12 = persister.orchestration_stacks_resources.lazy_find(
        {
          :stack   => lazy_find_stack_1_12,
          :ems_ref => orchestration_stack_resource_data("1_12_1")[:ems_ref]
        },
        {:ref => :by_stack_and_ems_ref,
         :key => :stack},
      ).load

      expect(persister.orchestration_stacks_resources.index_proxy.send(:local_db_indexes)[:by_stack_and_ems_ref].send(:index).keys).to(
        match_array(
          [
            "stack_ems_ref_1_11__stack_resource_physical_resource_1_11_1",
            "stack_ems_ref_1_11__stack_resource_physical_resource_1_11_2",
            "stack_ems_ref_1_12__stack_resource_physical_resource_1_12_1",
          ]
        )
      )

      expect(stack_resource_1_11_1.manager_uuid).to eq "stack_resource_physical_resource_1_11_1"
      expect(stack_resource_1_11_2.manager_uuid).to eq "stack_resource_physical_resource_1_11_2"
      expect(stack_resource_1_11_3).to be_nil
      # TODO(lsmola) should we preload the relation even before the scanner found it it's referenced?
      # :key pointing to relation is not loaded when scanner is not invoked
      expect(stack_1_12).to be_nil
    end
  end

  context "check secondary indexes on Vms" do
    it "finds Vm by name" do
      vm1 = persister.vms.lazy_find({:name => vm_data(1)[:name]}, {:ref => :by_name}).load
      expect(vm1[:ems_ref]).to eq "vm_ems_ref_1"

      expect(persister.vms.index_proxy.send(:local_db_indexes)[:by_name].send(:index).keys).to(
        match_array(
          [
            "vm_name_1",
          ]
        )
      )

      vm1 = persister.vms.find({:name => vm_data(1)[:name]}, {:ref => :by_name})
      expect(vm1[:ems_ref]).to eq "vm_ems_ref_1"

      expect(persister.vms.index_proxy.send(:local_db_indexes)[:by_name].send(:index).keys).to(
        match_array(
          [
            "vm_name_1",
          ]
        )
      )
    end

    it "finds Vm by uid_ems and name" do
      vm1 = persister.vms.lazy_find({:name => vm_data(1)[:name], :uid_ems => vm_data(1)[:uid_ems]}, {:ref => :by_uid_ems_and_name}).load
      expect(vm1[:ems_ref]).to eq "vm_ems_ref_1"

      expect(persister.vms.index_proxy.send(:local_db_indexes)[:by_uid_ems_and_name].send(:index).keys).to(
        match_array(
          [
            "vm_uid_ems_1__vm_name_1",
          ]
        )
      )

      vm1 = persister.vms.find({:uid_ems => vm_data(1)[:uid_ems], :name => vm_data(1)[:name]}, {:ref => :by_uid_ems_and_name})
      expect(vm1[:ems_ref]).to eq "vm_ems_ref_1"

      expect(persister.vms.index_proxy.send(:local_db_indexes)[:by_uid_ems_and_name].send(:index).keys).to(
        match_array(
          [
            "vm_uid_ems_1__vm_name_1",
          ]
        )
      )
    end
  end

  context "check secondary index with polymorphic relation inside" do
    it "will fail trying to build query using polymorphic column as index" do
      lazy_find_vm1 = persister.vms.lazy_find(:ems_ref => vm_data(1)[:ems_ref])

      # TODO(lsmola) Will we need to search by polymorphic columns? We do not do that now in any refresh. By design,
      # polymoprhic columns can't do join (they can, only for 1 table). Maybe union of 1 table joins using polymorphic
      # relations?
      # TODO(lsmola) We should probably assert this sooner? Now we are getting a failure trying to add :device in
      # .includes
      expect { persister.network_ports.lazy_find({:device => lazy_find_vm1}, {:ref => :by_device}).load }.to(
        raise_error(ActiveRecord::EagerLoadPolymorphicError,
                    "Cannot eagerly load the polymorphic association :device")
      )
    end
  end

  context "check validity of defined index" do
    it "checks primary index attributes exist" do
      expect do
        persister.add_collection(persister.send(:cloud),
                                 :vms,
                                 :manager_ref => %i(ems_ref ems_gref))
      end.to raise_error("Invalid definition of index :manager_ref, there is no attribute :ems_gref on model Vm")
    end

    it "checks secondary index attributes exist" do
      expect do
        persister.add_collection(persister.send(:cloud),
                                 :vms,
                                 :secondary_refs => {:by_uid_ems_and_name => %i(uid_emsa name)})
      end.to raise_error("Invalid definition of index :by_uid_ems_and_name, there is no attribute :uid_emsa on model Vm")
    end

    it "checks relation is allowed in index" do
      persister.add_collection(persister.send(:cloud), :vms) do |builder|
        builder.add_properties(:model_class    => ::ManageIQ::Providers::CloudManager::Vm,
                               :secondary_refs => {:by_availability_zone_and_name => %i(availability_zone name)})
      end

      expect(persister.vms.index_proxy.send(:data_indexes).keys).to match_array(%i(manager_ref by_availability_zone_and_name))
    end

    it "checks relation is on model class" do
      expect do
        persister.add_collection(persister.send(:cloud), :vms) do |builder|
          builder.add_properties(:secondary_refs => {:by_availability_zone_and_name => %i(availability_zone name)})
        end
      end.to raise_error("Invalid definition of index :by_availability_zone_and_name, there is no attribute :availability_zone on model Vm")
    end

    it "checks we allow any index attributes when we use custom_saving block" do
      persister.add_collection(persister.send(:cloud), :vms) do |builder|
        builder.add_properties(
          :custom_save_block => ->(ems, _ic) { ems },
          :manager_ref       => %i(a b c)
        )
      end

      expect(persister.vms.index_proxy.send(:data_indexes).keys).to match_array([:manager_ref])
    end
  end
end
