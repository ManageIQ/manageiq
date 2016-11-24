require_relative 'spec_parsed_data'

describe ManagerRefresh::SaveInventory do
  include SpecParsedData

  context 'one DtoCollection with Vm data' do
    before(:each) do
      @zone = FactoryGirl.create(:zone)
      @ems  = FactoryGirl.create(:ems_cloud, :zone => @zone)
    end

    context 'with no Vms in the DB' do
      it 'creates VMs' do
        # Initialize the DtoCollections
        data       = {}
        data[:vms] = ::ManagerRefresh::DtoCollection.new(
          ManageIQ::Providers::Amazon::CloudManager::Vm, :parent => @ems, :association => :vms)

        # Fill the DtoCollections with data
        add_data_to_dto_collection(data[:vms], vm_data(1), vm_data(2))

        # Invoke the DtoCollections saving
        ManagerRefresh::SaveInventory.save_inventory(@ems, data)

        # Assert saved data
        assert_all_records_match_hashes(
          [Vm.all, @ems.vms],
          {:ems_ref => "vm_ems_ref_1", :name => "vm_name_1", :location => "vm_location_1"},
          {:ems_ref => "vm_ems_ref_2", :name => "vm_name_2", :location => "vm_location_2"})
      end

      it 'creates and updates VMs' do
        # Initialize the DtoCollections
        data       = {}
        data[:vms] = ::ManagerRefresh::DtoCollection.new(
          ManageIQ::Providers::Amazon::CloudManager::Vm, :parent => @ems, :association => :vms)

        # Fill the DtoCollections with data
        add_data_to_dto_collection(data[:vms],
                                   vm_data(1),
                                   vm_data(2))

        # Invoke the DtoCollections saving
        ManagerRefresh::SaveInventory.save_inventory(@ems, data)

        # Assert that saved data have the updated values, checking id to make sure the original records are updated
        assert_all_records_match_hashes(
          [Vm.all, @ems.vms],
          {:ems_ref => "vm_ems_ref_1", :name => "vm_name_1", :location => "vm_location_1"},
          {:ems_ref => "vm_ems_ref_2", :name => "vm_name_2", :location => "vm_location_2"})

        # Fetch the created Vms from the DB
        vm1        = Vm.find_by(:ems_ref => "vm_ems_ref_1")
        vm2        = Vm.find_by(:ems_ref => "vm_ems_ref_2")

        # Second saving with the updated data
        # Initialize the DtoCollections
        data       = {}
        data[:vms] = ::ManagerRefresh::DtoCollection.new(
          ManageIQ::Providers::Amazon::CloudManager::Vm, :parent => @ems, :association => :vms)

        # Fill the DtoCollections with data, that have a modified name
        add_data_to_dto_collection(data[:vms],
                                   vm_data(1).merge(:name => "vm_changed_name_1"),
                                   vm_data(2).merge(:name => "vm_changed_name_2"))

        # Invoke the DtoCollections saving
        ManagerRefresh::SaveInventory.save_inventory(@ems, data)

        # Assert that saved data have the updated values, checking id to make sure the original records are updated
        assert_all_records_match_hashes(
          [Vm.all, @ems.vms],
          {:id => vm1.id, :ems_ref => "vm_ems_ref_1", :name => "vm_changed_name_1", :location => "vm_location_1"},
          {:id => vm2.id, :ems_ref => "vm_ems_ref_2", :name => "vm_changed_name_2", :location => "vm_location_2"})
      end
    end

    context 'with existing Vms in the DB' do
      before :each do
        # Fill DB with test Vms
        @vm1 = FactoryGirl.create(:vm_cloud, vm_data(1).merge(:ext_management_system => @ems))
        @vm2 = FactoryGirl.create(:vm_cloud, vm_data(2).merge(:ext_management_system => @ems))
      end

      context 'with VM DtoCollection with default settings' do
        before :each do
          # Initialize the DtoCollections
          @data       = {}
          @data[:vms] = ::ManagerRefresh::DtoCollection.new(
            ManageIQ::Providers::Amazon::CloudManager::Vm, :parent => @ems, :association => :vms)
        end

        it 'has correct records in the DB' do
          # Check we really have the expected Vms in the DB
          assert_all_records_match_hashes(
            [Vm.all, @ems.vms],
            {:ems_ref => "vm_ems_ref_1", :name => "vm_name_1", :location => "vm_location_1"},
            {:ems_ref => "vm_ems_ref_2", :name => "vm_name_2", :location => "vm_location_2"})
        end

        it 'updates existing VMs' do
          # Fill the DtoCollections with data, that have a modified name
          add_data_to_dto_collection(@data[:vms],
                                     vm_data(1).merge(:name => "vm_changed_name_1"),
                                     vm_data(2).merge(:name => "vm_changed_name_2"))

          # Invoke the DtoCollections saving
          ManagerRefresh::SaveInventory.save_inventory(@ems, @data)

          # Assert that saved data have the updated values, checking id to make sure the original records are updated
          assert_all_records_match_hashes(
            [Vm.all, @ems.vms],
            {:id => @vm1.id, :ems_ref => "vm_ems_ref_1", :name => "vm_changed_name_1", :location => "vm_location_1"},
            {:id => @vm2.id, :ems_ref => "vm_ems_ref_2", :name => "vm_changed_name_2", :location => "vm_location_2"})
        end

        it 'creates new VMs' do
          # Fill the DtoCollections with data, that have a new VM
          add_data_to_dto_collection(@data[:vms],
                                     vm_data(1).merge(:name => "vm_changed_name_1"),
                                     vm_data(2).merge(:name => "vm_changed_name_2"),
                                     vm_data(3).merge(:name => "vm_changed_name_3"))

          # Invoke the DtoCollections saving
          ManagerRefresh::SaveInventory.save_inventory(@ems, @data)

          # Assert that saved data contain the new VM
          assert_all_records_match_hashes(
            [Vm.all, @ems.vms],
            {:id => @vm1.id, :ems_ref => "vm_ems_ref_1", :name => "vm_changed_name_1", :location => "vm_location_1"},
            {:id => @vm2.id, :ems_ref => "vm_ems_ref_2", :name => "vm_changed_name_2", :location => "vm_location_2"},
            {:id => anything, :ems_ref => "vm_ems_ref_3", :name => "vm_changed_name_3", :location => "vm_location_3"})
        end

        it 'deletes missing VMs' do
          # Fill the DtoCollections with data, that are missing one VM
          add_data_to_dto_collection(@data[:vms],
                                     vm_data(1).merge(:name => "vm_changed_name_1"))

          # Invoke the DtoCollections saving
          ManagerRefresh::SaveInventory.save_inventory(@ems, @data)

          # Assert that saved data do miss the deleted VM
          assert_all_records_match_hashes(
            [Vm.all, @ems.vms],
            {:id => @vm1.id, :ems_ref => "vm_ems_ref_1", :name => "vm_changed_name_1", :location => "vm_location_1"})
        end

        it 'deletes missing and creates new VMs' do
          # Fill the DtoCollections with data, that have one new VM and are missing one VM
          add_data_to_dto_collection(@data[:vms],
                                     vm_data(1).merge(:name => "vm_changed_name_1"),
                                     vm_data(3).merge(:name => "vm_changed_name_3"))

          # Invoke the DtoCollections saving
          ManagerRefresh::SaveInventory.save_inventory(@ems, @data)

          # Assert that saved data have the new VM and miss the deleted VM
          assert_all_records_match_hashes(
            [Vm.all, @ems.vms],
            {:id => @vm1.id, :ems_ref => "vm_ems_ref_1", :name => "vm_changed_name_1", :location => "vm_location_1"},
            {:id => anything, :ems_ref => "vm_ems_ref_3", :name => "vm_changed_name_3", :location => "vm_location_3"})
        end
      end

      context 'with VM DtoCollection with :delete_method => :disconnect_inv' do
        before :each do
          # Initialize the DtoCollections
          @data       = {}
          @data[:vms] = ::ManagerRefresh::DtoCollection.new(
            ManageIQ::Providers::Amazon::CloudManager::Vm,
            :parent        => @ems,
            :association   => :vms,
            :delete_method => :disconnect_inv)
        end

        it 'disconnects a missing VM instead of deleting it' do
          # Fill the DtoCollections with data, that have a modified name, new VM and a missing VM
          add_data_to_dto_collection(@data[:vms],
                                     vm_data(1).merge(:name => "vm_changed_name_1"),
                                     vm_data(3).merge(:name => "vm_changed_name_3"))

          # Invoke the DtoCollections saving
          ManagerRefresh::SaveInventory.save_inventory(@ems, @data)

          # Assert that DB still contains the disconnected VMs
          assert_all_records_match_hashes(
            Vm.all,
            {:id => @vm1.id, :ems_ref => "vm_ems_ref_1", :name => "vm_changed_name_1", :location => "vm_location_1"},
            {:id => @vm2.id, :ems_ref => "vm_ems_ref_2", :name => "vm_name_2", :location => "vm_location_2"},
            {:id => anything, :ems_ref => "vm_ems_ref_3", :name => "vm_changed_name_3", :location => "vm_location_3"})

          # Assert that ems do not have the disconnected VMs associated
          assert_all_records_match_hashes(
            @ems.vms,
            {:id => @vm1.id, :ems_ref => "vm_ems_ref_1", :name => "vm_changed_name_1", :location => "vm_location_1"},
            {:id => anything, :ems_ref => "vm_ems_ref_3", :name => "vm_changed_name_3", :location => "vm_location_3"})
        end
      end

      context 'with VM DtoCollection blacklist or whitelist used' do
        let :changed_data do
          [
            vm_data(1).merge(:name            => "vm_changed_name_1",
                             :location        => "vm_changed_location_1",
                             :uid_ems         => "uid_ems_changed_1",
                             :raw_power_state => "raw_power_state_changed_1"),
            vm_data(2).merge(:name            => "vm_changed_name_2",
                             :location        => "vm_changed_location_2",
                             :uid_ems         => "uid_ems_changed_2",
                             :raw_power_state => "raw_power_state_changed_2"),
            vm_data(3).merge(:name            => "vm_changed_name_3",
                             :location        => "vm_changed_location_3",
                             :uid_ems         => "uid_ems_changed_3",
                             :raw_power_state => "raw_power_state_changed_3")
          ]
        end

        # TODO(lsmola) fixed attributes should contain also other attributes, like inclusion validation of :vendor
        # column
        it 'recognizes correct presence validators' do
          dto_collection      = ::ManagerRefresh::DtoCollection.new(
            ManageIQ::Providers::Amazon::CloudManager::Vm,
            :parent               => @ems,
            :association          => :vms,
            :attributes_blacklist => [:ems_ref, :uid_ems, :name, :location])

          # Check that :name and :location do have validate presence, those attributes will not be blacklisted
          presence_validators = dto_collection.model_class.validators
                                  .detect { |x| x.kind_of? ActiveRecord::Validations::PresenceValidator }.attributes

          expect(presence_validators).to include(:name)
          expect(presence_validators).to include(:location)
        end

        it 'does not blacklist fixed attributes with default manager_ref' do
          # Fixed attributes are attributes used for unique ID of the DTO or attributes with presence validation
          dto_collection = ::ManagerRefresh::DtoCollection.new(
            ManageIQ::Providers::Amazon::CloudManager::Vm,
            :parent               => @ems,
            :association          => :vms,
            :attributes_blacklist => [:ems_ref, :uid_ems, :name, :location, :vendor, :raw_power_state])

          expect(dto_collection.attributes_blacklist).to match_array([:vendor, :uid_ems, :raw_power_state])
        end

        it 'has fixed and internal attributes amongst whitelisted_attributes with default manager_ref' do
          # Fixed attributes are attributes used for unique ID of the DTO or attributes with presence validation
          dto_collection = ::ManagerRefresh::DtoCollection.new(
            ManageIQ::Providers::Amazon::CloudManager::Vm,
            :parent               => @ems,
            :association          => :vms,
            :attributes_whitelist => [:raw_power_state])

          expect(dto_collection.attributes_whitelist).to match_array([:__feedback_edge_set_parent, :ems_ref,
                                                                      :name, :location, :raw_power_state])
        end

        it 'does not blacklist fixed attributes when changing manager_ref' do
          dto_collection = ::ManagerRefresh::DtoCollection.new(
            ManageIQ::Providers::Amazon::CloudManager::Vm,
            :manager_ref          => [:uid_ems],
            :parent               => @ems,
            :association          => :vms,
            :attributes_blacklist => [:ems_ref, :uid_ems, :name, :location, :vendor, :raw_power_state])

          expect(dto_collection.attributes_blacklist).to match_array([:vendor, :ems_ref, :raw_power_state])
        end

        it 'has fixed and internal attributes amongst whitelisted_attributes when changing manager_ref' do
          # Fixed attributes are attributes used for unique ID of the DTO or attributes with presence validation
          dto_collection = ::ManagerRefresh::DtoCollection.new(
            ManageIQ::Providers::Amazon::CloudManager::Vm,
            :manager_ref          => [:uid_ems],
            :parent               => @ems,
            :association          => :vms,
            :attributes_whitelist => [:raw_power_state])

          expect(dto_collection.attributes_whitelist).to match_array([:__feedback_edge_set_parent, :uid_ems, :name,
                                                                      :location, :raw_power_state])
        end

        it 'saves all attributes with blacklist and whitelist disabled' do
          # Initialize the DtoCollections
          @data       = {}
          @data[:vms] = ::ManagerRefresh::DtoCollection.new(
            ManageIQ::Providers::Amazon::CloudManager::Vm,
            :parent      => @ems,
            :association => :vms)

          # Fill the DtoCollections with data, that have a modified name, new VM and a missing VM
          add_data_to_dto_collection(@data[:vms], *changed_data)

          # Invoke the DtoCollections saving
          ManagerRefresh::SaveInventory.save_inventory(@ems, @data)

          # Assert that saved data don;t have the blacklisted attributes updated nor filled
          assert_all_records_match_hashes(
            [Vm.all, @ems.vms],
            {:id              => @vm1.id,
             :ems_ref         => "vm_ems_ref_1",
             :name            => "vm_changed_name_1",
             :raw_power_state => "raw_power_state_changed_1",
             :uid_ems         => "uid_ems_changed_1",
             :location        => "vm_changed_location_1"},
            {:id              => @vm2.id,
             :ems_ref         => "vm_ems_ref_2",
             :name            => "vm_changed_name_2",
             :raw_power_state => "raw_power_state_changed_2",
             :uid_ems         => "uid_ems_changed_2",
             :location        => "vm_changed_location_2"},
            {:id              => anything,
             :ems_ref         => "vm_ems_ref_3",
             :name            => "vm_changed_name_3",
             :raw_power_state => "raw_power_state_changed_3",
             :uid_ems         => "uid_ems_changed_3",
             :location        => "vm_changed_location_3"})
        end

        it 'does not save blacklisted attributes (excluding fixed attributes)' do
          # Initialize the DtoCollections
          @data       = {}
          @data[:vms] = ::ManagerRefresh::DtoCollection.new(
            ManageIQ::Providers::Amazon::CloudManager::Vm,
            :parent               => @ems,
            :association          => :vms,
            :attributes_blacklist => [:name, :location, :raw_power_state])

          # Fill the DtoCollections with data, that have a modified name, new VM and a missing VM
          add_data_to_dto_collection(@data[:vms], *changed_data)

          # Invoke the DtoCollections saving
          ManagerRefresh::SaveInventory.save_inventory(@ems, @data)

          # Assert that saved data don;t have the blacklisted attributes updated nor filled
          assert_all_records_match_hashes(
            [Vm.all, @ems.vms],
            {:id              => @vm1.id,
             :ems_ref         => "vm_ems_ref_1",
             :name            => "vm_changed_name_1",
             :raw_power_state => "unknown",
             :uid_ems         => "uid_ems_changed_1",
             :location        => "vm_changed_location_1"},
            {:id              => @vm2.id,
             :ems_ref         => "vm_ems_ref_2",
             :name            => "vm_changed_name_2",
             :raw_power_state => "unknown",
             :uid_ems         => "uid_ems_changed_2",
             :location        => "vm_changed_location_2"},
            {:id              => anything,
             :ems_ref         => "vm_ems_ref_3",
             :name            => "vm_changed_name_3",
             :raw_power_state => nil,
             :uid_ems         => "uid_ems_changed_3",
             :location        => "vm_changed_location_3"})
        end

        it 'saves only whilelisted attributes (including fixed attributes)' do
          # Initialize the DtoCollections
          @data       = {}
          @data[:vms] = ::ManagerRefresh::DtoCollection.new(
            ManageIQ::Providers::Amazon::CloudManager::Vm,
            :parent               => @ems,
            :association          => :vms,
            # TODO(lsmola) vendor is not getting caught by fixed attributes
            :attributes_whitelist => [:uid_ems, :vendor])

          # Fill the DtoCollections with data, that have a modified name, new VM and a missing VM
          add_data_to_dto_collection(@data[:vms], *changed_data)

          # Invoke the DtoCollections saving
          ManagerRefresh::SaveInventory.save_inventory(@ems, @data)

          # Assert that saved data don;t have the blacklisted attributes updated nor filled
          assert_all_records_match_hashes(
            [Vm.all, @ems.vms],
            {:id              => @vm1.id,
             :ems_ref         => "vm_ems_ref_1",
             :name            => "vm_changed_name_1",
             :raw_power_state => "unknown",
             :uid_ems         => "uid_ems_changed_1",
             :location        => "vm_changed_location_1"},
            {:id              => @vm2.id,
             :ems_ref         => "vm_ems_ref_2",
             :name            => "vm_changed_name_2",
             :raw_power_state => "unknown",
             :uid_ems         => "uid_ems_changed_2",
             :location        => "vm_changed_location_2"},
            {:id              => anything,
             :ems_ref         => "vm_ems_ref_3",
             :name            => "vm_changed_name_3",
             :raw_power_state => nil,
             :uid_ems         => "uid_ems_changed_3",
             :location        => "vm_changed_location_3"})
        end

        it 'saves correct set of attributes when both whilelist and blacklist are used' do
          # Initialize the DtoCollections
          @data       = {}
          @data[:vms] = ::ManagerRefresh::DtoCollection.new(
            ManageIQ::Providers::Amazon::CloudManager::Vm,
            :parent               => @ems,
            :association          => :vms,
            # TODO(lsmola) vendor is not getting caught by fixed attributes
            :attributes_whitelist => [:uid_ems, :raw_power_state, :vendor],
            :attributes_blacklist => [:name, :ems_ref, :raw_power_state])

          # Fill the DtoCollections with data, that have a modified name, new VM and a missing VM
          add_data_to_dto_collection(@data[:vms], *changed_data)

          # Invoke the DtoCollections saving
          ManagerRefresh::SaveInventory.save_inventory(@ems, @data)

          # Assert that saved data don;t have the blacklisted attributes updated nor filled
          assert_all_records_match_hashes(
            [Vm.all, @ems.vms],
            {:id              => @vm1.id,
             :ems_ref         => "vm_ems_ref_1",
             :name            => "vm_changed_name_1",
             :raw_power_state => "unknown",
             :uid_ems         => "uid_ems_changed_1",
             :location        => "vm_changed_location_1"},
            {:id              => @vm2.id,
             :ems_ref         => "vm_ems_ref_2",
             :name            => "vm_changed_name_2",
             :raw_power_state => "unknown",
             :uid_ems         => "uid_ems_changed_2",
             :location        => "vm_changed_location_2"},
            {:id              => anything,
             :ems_ref         => "vm_ems_ref_3",
             :name            => "vm_changed_name_3",
             :raw_power_state => nil,
             :uid_ems         => "uid_ems_changed_3",
             :location        => "vm_changed_location_3"})
        end
      end

      context 'with VM DtoCollection with :complete => false' do
        before :each do
          # Initialize the DtoCollections
          @data       = {}
          @data[:vms] = ::ManagerRefresh::DtoCollection.new(
            ManageIQ::Providers::Amazon::CloudManager::Vm,
            :parent      => @ems,
            :association => :vms,
            :complete    => false)
        end

        it 'only updates existing Vms and creates new VMs, does not delete or update missing VMs' do
          # Fill the DtoCollections with data, that have a new VM
          add_data_to_dto_collection(@data[:vms],
                                     vm_data(1).merge(:name => "vm_changed_name_1"),
                                     vm_data(3).merge(:name => "vm_changed_name_3"))

          # Invoke the DtoCollections saving
          ManagerRefresh::SaveInventory.save_inventory(@ems, @data)

          # Assert that saved data contain the new VM, but no VM was deleted
          assert_all_records_match_hashes(
            [Vm.all, @ems.vms],
            {:id => @vm1.id, :ems_ref => "vm_ems_ref_1", :name => "vm_changed_name_1", :location => "vm_location_1"},
            {:id => @vm2.id, :ems_ref => "vm_ems_ref_2", :name => "vm_name_2", :location => "vm_location_2"},
            {:id => anything, :ems_ref => "vm_ems_ref_3", :name => "vm_changed_name_3", :location => "vm_location_3"})
        end
      end
    end
  end

  def assert_all_records_match_hashes(model_classes, *expected_match)
    # Helper for matching attributes of the model's records to an Array of hashes
    model_classes = model_classes.kind_of?(Array) ? model_classes : [model_classes]
    attributes    = expected_match.first.keys
    model_classes.each { |m| expect(m.to_a.map { |x| x.slice(*attributes) }).to(match_array(expected_match)) }
  end

  def add_data_to_dto_collection(dto_collection, *args)
    # Creates Dto object from each arg and adds it into the DtoCollection
    args.each { |data| dto_collection << dto_collection.new_dto(data) }
  end
end
