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
