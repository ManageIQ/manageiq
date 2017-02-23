require_relative 'spec_helper'
require_relative 'spec_parsed_data'
require_relative 'init_data_helper'

describe ManagerRefresh::SaveInventory do
  include SpecHelper
  include SpecParsedData
  include InitDataHelper

  ######################################################################################################################
  # Spec scenarios for different strategies and optimizations using references
  ######################################################################################################################
  #
  # Test all settings for ManagerRefresh::SaveInventory
  [{:inventory_object_saving_strategy => nil},
   {:inventory_object_saving_strategy => :recursive}].each do |inventory_object_settings|
    context "with settings #{inventory_object_settings}" do
      before :each do
        @zone = FactoryGirl.create(:zone)
        @ems  = FactoryGirl.create(:ems_cloud, :zone => @zone, :network_manager => FactoryGirl.create(:ems_network, :zone => @zone))

        allow(@ems.class).to receive(:ems_type).and_return(:mock)
        allow(Settings.ems_refresh).to receive(:mock).and_return(inventory_object_settings)
      end

      before :each do
        @image1 = FactoryGirl.create(:miq_template, image_data(1).merge(:ext_management_system => @ems))
        @image2 = FactoryGirl.create(:miq_template, image_data(2).merge(:ext_management_system => @ems))
        @image3 = FactoryGirl.create(:miq_template, image_data(3).merge(:ext_management_system => @ems))

        @image_hardware1 = FactoryGirl.create(
          :hardware,
          image_hardware_data(1).merge(
            :guest_os       => "linux_generic_1",
            :vm_or_template => @image1
          )
        )
        @image_hardware2 = FactoryGirl.create(
          :hardware,
          image_hardware_data(2).merge(
            :guest_os       => "linux_generic_2",
            :vm_or_template => @image2
          )
        )
        @image_hardware3 = FactoryGirl.create(
          :hardware,
          image_hardware_data(3).merge(
            :guest_os       => "linux_generic_3",
            :vm_or_template => @image3
          )
        )

        @key_pair1  = FactoryGirl.create(:auth_key_pair_cloud, key_pair_data(1).merge(:resource => @ems))
        @key_pair12 = FactoryGirl.create(:auth_key_pair_cloud, key_pair_data(12).merge(:resource => @ems))
        @key_pair2  = FactoryGirl.create(:auth_key_pair_cloud, key_pair_data(2).merge(:resource => @ems))
        @key_pair3  = FactoryGirl.create(:auth_key_pair_cloud, key_pair_data(3).merge(:resource => @ems))

        @vm1 = FactoryGirl.create(
          :vm_cloud,
          vm_data(1).merge(
            :flavor           => @flavor_1,
            :genealogy_parent => @image1,
            :key_pairs        => [@key_pair1],
            :location         => 'host_10_10_10_1.com',
          )
        )
        @vm12 = FactoryGirl.create(
          :vm_cloud,
          vm_data(12).merge(
            :flavor           => @flavor1,
            :genealogy_parent => @image1,
            :key_pairs        => [@key_pair1, @key_pair12],
            :location         => 'host_10_10_10_12.com',
          )
        )
        @vm2 = FactoryGirl.create(
          :vm_cloud,
          vm_data(2).merge(
            :flavor           => @flavor2,
            :genealogy_parent => @image2,
            :key_pairs        => [@key_pair2],
            :location         => 'host_10_10_10_2.com',
          )
        )
        @vm4 = FactoryGirl.create(
          :vm_cloud,
          vm_data(4).merge(
            :location              => 'default_value_unknown',
            :ext_management_system => @ems
          )
        )

        @hardware1 = FactoryGirl.create(
          :hardware,
          hardware_data(1).merge(
            :guest_os       => @image1.hardware.guest_os,
            :vm_or_template => @vm1
          )
        )
        @hardware12 = FactoryGirl.create(
          :hardware,
          hardware_data(12).merge(
            :guest_os       => @image1.hardware.guest_os,
            :vm_or_template => @vm12
          )
        )
        @hardware2 = FactoryGirl.create(
          :hardware,
          hardware_data(2).merge(
            :guest_os       => @image2.hardware.guest_os,
            :vm_or_template => @vm2
          )
        )

        @network_port1 = FactoryGirl.create(
          :network_port,
          network_port_data(1).merge(
            :device => @vm1
          )
        )

        @network_port12 = FactoryGirl.create(
          :network_port,
          network_port_data(12).merge(
            :device => @vm1
          )
        )

        @network_port2 = FactoryGirl.create(
          :network_port,
          network_port_data(2).merge(
            :device => @vm2
          )
        )
      end

      it "tests that a key pointing to a relation is filled correctly when coming from db" do
        vm_refs = ["vm_ems_ref_3", "vm_ems_ref_4"]
        network_port_refs = ["network_port_ems_ref_1"]

        # Setup InventoryCollections
        @data = {}
        @data[:network_ports] = ::ManagerRefresh::InventoryCollection.new(
          network_ports_init_data(
            :parent   => @ems.network_manager,
            :arel     => @ems.network_manager.network_ports.where(:ems_ref => network_port_refs),
            :strategy => :local_db_find_missing_references
          )
        )
        @data[:hardwares] = ::ManagerRefresh::InventoryCollection.new(
          hardwares_init_data(
            :arel     => @ems.hardwares.joins(:vm_or_template).where(:vms => {:ems_ref => vm_refs}),
            :strategy => :local_db_find_references
          )
        )

        @network_port_data_1 = network_port_data(1).merge(
          :device => @data[:hardwares].lazy_find(vm_data(1)[:ems_ref], :key => :vm_or_template)
        )

        # Fill InventoryCollections with data
        add_data_to_inventory_collection(@data[:network_ports],
                                         @network_port_data_1)

        # Assert data before save
        @network_port1.device = nil
        @network_port1.save
        @network_port1.reload
        expect(@network_port1.device).to eq nil

        # Invoke the InventoryCollections saving
        ManagerRefresh::SaveInventory.save_inventory(@ems, @data.values)

        # Asset saved data
        @network_port1.reload
        @vm1.reload
        expect(@network_port1.device).to eq @vm1
      end

      it "tests that a key pointing to a polymorphic relation is filled correctly when coming from db" do
        network_port_refs = ["network_port_ems_ref_1"]

        # Setup InventoryCollections
        @data = {}
        @data[:network_ports] = ::ManagerRefresh::InventoryCollection.new(
          network_ports_init_data(
            :parent   => @ems.network_manager,
            :arel     => @ems.network_manager.network_ports.where(:ems_ref => network_port_refs),
            :strategy => :local_db_find_missing_references
          )
        )
        @data[:db_network_ports] = ::ManagerRefresh::InventoryCollection.new(
          network_ports_init_data(
            :parent   => @ems.network_manager,
            :strategy => :local_db_find_references
          )
        )

        @network_port_data_1 = network_port_data(1).merge(
          :device => @data[:db_network_ports].lazy_find(network_port_data(12)[:ems_ref], :key => :device)
        )

        # Fill InventoryCollections with data
        add_data_to_inventory_collection(@data[:network_ports],
                                         @network_port_data_1)

        # Assert data before save
        @network_port1.device = nil
        @network_port1.save
        @network_port1.reload
        expect(@network_port1.device).to eq nil

        # Invoke the InventoryCollections saving
        ManagerRefresh::SaveInventory.save_inventory(@ems, @data.values)

        # Asset saved data
        @network_port1.reload
        @vm1.reload
        expect(@network_port1.device).to eq @vm1
      end
    end
  end
end
