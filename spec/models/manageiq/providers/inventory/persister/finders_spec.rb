require_relative 'helpers/spec_parsed_data'
require_relative 'test_persister'
require_relative 'targeted_refresh_spec_helper'

RSpec.describe ManageIQ::Providers::Inventory::Persister do
  include SpecParsedData
  include TargetedRefreshSpecHelper

  ######################################################################################################################
  # Spec scenarios for asserts giving hints to developers
  ######################################################################################################################
  #
  before do
    @ems = FactoryBot.create(:ems_cloud)
  end

  let(:persister) { create_persister }

  it "raises an exception when relation object is needed, but something else is provided" do
    expected_error = "Wrong index for key :vm_or_template, the value must be of type Nil or InventoryObject or InventoryObjectLazy, got: not_allowed_string"
    expect do
      persister.hardwares.lazy_find(:vm_or_template => "not_allowed_string")
    end.to(raise_error(expected_error))

    expect do
      persister.hardwares.lazy_find("not_allowed_string")
    end.to(raise_error(expected_error))
  end

  it "raises an exception when composite index is expected by finder, but 1 value is passed instead" do
    expected_error = "The index :manager_ref has composite index, finder has to be called as: collection.find(:hardware => 'X', :device_name => 'X')"
    expect do
      persister.disks.lazy_find("unknown__public", :key => :device_name, :default => 'default_device_name')
    end.to(raise_error(expected_error))
  end

  it "raises an exception passing bad primary index used by finder" do
    expected_error = "Finder has missing keys for index :manager_ref, missing indexes are: [:hardware]"
    expect do
      persister.networks.lazy_find(:hardwares => "something", :description => "public")
    end.to(raise_error(expected_error))

    expected_error = "Finder has missing keys for index :manager_ref, missing indexes are: [:ems_ref]"
    expect do
      persister.vms.lazy_find(:ems_ruf => "some_ems_ref")
    end.to(raise_error(expected_error))
  end

  it "raises an exception passing bad secondsry index used by finder" do
    expected_error = "Finder has missing keys for index :by_name, missing indexes are: [:name]"
    expect do
      persister.vms.lazy_find({:names => "name"}, {:ref => :by_name})
    end.to(raise_error(expected_error))

    expected_error = "Finder has missing keys for index :by_uid_ems_and_name, missing indexes are: [:uid_ems, :name]"
    expect do
      persister.vms.lazy_find({:names => "name", :uida_ems => "uid_ems"}, {:ref => :by_uid_ems_and_name})
    end.to(raise_error(expected_error))
  end

  it "checks that we recognize first argument vs passed kwargs" do
    # This passes nicely
    lazy_vm = persister.vms.lazy_find({:name => "name"}, :ref => :by_name)
    expect(lazy_vm.reference.full_reference).to eq(:name => "name")

    # TODO(lsmola) But this fails, since it takes the whole hash as 1st arg, it should correctly raise invalid format
    expected_error = "Finder has missing keys for index :manager_ref, missing indexes are: [:ems_ref]"
    expect do
      persister.vms.lazy_find(:name => "name", :ref => :by_name)
    end.to(raise_error(expected_error))

    # TODO(lsmola) And this doesn't fail, but the :key is silently ignored, it should also raise invalid format
    lazy_vm = persister.vms.lazy_find(:ems_ref => "ems_ref_1", :key => :name)
    expect(lazy_vm.reference.full_reference).to eq(:ems_ref => "ems_ref_1", :key => :name)
  end

  it "checks passing more keys to index passes just fine" do
    # There is not need to force exact match as long as all keys of the index are passed
    vm_lazy_1 = persister.vms.lazy_find({:name => "name", :uid_ems => "uid_ems", :ems_ref => "ems_ref"}, {:ref => :by_uid_ems_and_name})

    expect(vm_lazy_1.reference.full_reference).to eq(:name => "name", :uid_ems => "uid_ems", :ems_ref => "ems_ref")
    expect(vm_lazy_1.ref).to eq(:by_uid_ems_and_name)
    expect(vm_lazy_1.to_s).to eq("uid_ems__name")

    vm_lazy_2 = persister.vms.lazy_find(:name => "name", :uid_ems => "uid_ems", :ems_ref => "ems_ref")
    expect(vm_lazy_2.reference.full_reference).to eq(:name => "name", :uid_ems => "uid_ems", :ems_ref => "ems_ref")
    expect(vm_lazy_2.ref).to eq(:manager_ref)
    expect(vm_lazy_2.to_s).to eq("ems_ref")
  end

  it "checks passing composite index doesn't depend on order" do
    lazy_find_vm       = persister.vms.lazy_find(:ems_ref => "ems_ref_1")
    lazy_find_hardware = persister.hardwares.lazy_find(:vm_or_template => lazy_find_vm)

    lazy_find_network_1 = persister.networks.lazy_find(:hardware => lazy_find_hardware, :description => "public")
    lazy_find_network_2 = persister.networks.lazy_find(:description => "public", :hardware => lazy_find_hardware)

    expect(lazy_find_network_1.to_s).to eq("ems_ref_1__public")
    expect(lazy_find_network_1.to_s).to eq(lazy_find_network_2.to_s)
  end

  it "checks non composite index is allowed as non hash" do
    ems_ref   = "vm_ems_ref_1"
    vm_lazy_1 = persister.vms.lazy_find(:ems_ref => ems_ref)
    vm_lazy_2 = persister.vms.lazy_find(ems_ref)

    # Check the stringified reference matches
    expect(vm_lazy_1.to_s).to eq ems_ref
    expect(vm_lazy_1.stringified_reference).to eq ems_ref
    expect(vm_lazy_1.reference.stringified_reference).to eq ems_ref
    expect(vm_lazy_1.to_s).to eq vm_lazy_2.to_s

    # Check the full reference matches
    expect(vm_lazy_1.reference.full_reference).to eq(:ems_ref => ems_ref)
    expect(vm_lazy_1.reference.full_reference).to eq(vm_lazy_2.reference.full_reference)
  end

  it "checks non composite relation index is allowed as non hash" do
    ems_ref = "vm_ems_ref_1"
    vm_lazy = persister.vms.lazy_find(:ems_ref => ems_ref)

    hardware_lazy_1 = persister.hardwares.lazy_find(vm_lazy)
    hardware_lazy_2 = persister.hardwares.lazy_find(:vm_or_template => vm_lazy)

    # Check the stringified reference matches
    expect(hardware_lazy_1.to_s).to eq ems_ref
    expect(hardware_lazy_1.to_s).to eq hardware_lazy_2.to_s

    # Check the full reference matches
    expect(hardware_lazy_1.reference.full_reference).to eq(:vm_or_template => vm_lazy)
    expect(hardware_lazy_2.reference.full_reference).to eq hardware_lazy_2.reference.full_reference
  end

  it "checks build finds existing inventory object instead of duplicating" do
    expect(persister.vms.build(vm_data(1)).object_id).to eq(persister.vms.build(vm_data(1)).object_id)
  end

  it "checks find_or_build finds existing inventory object instead of duplicating" do
    expect(persister.vms.find_or_build(vm_data(1)).object_id).to eq(persister.vms.find_or_build(vm_data(1)).object_id)
  end

  it "checks find_or_build_by finds existing inventory object instead of duplicating" do
    expect(persister.vms.find_or_build_by(vm_data(1)).object_id).to eq(persister.vms.find_or_build_by(vm_data(1)).object_id)
  end

  it "raises exception unless only primary index is used in nested lazy_find when building" do
    name = vm_data(1)[:name]
    vm_lazy = persister.vms.lazy_find({:name => name}, :ref => :by_name)

    persister.vms.build(vm_data(1))

    expected_error = "Wrong index for key :vm_or_template, all references under this index must point to default :ref"\
                     " called :manager_ref. Any other :ref is not valid. This applies also to nested lazy links."
    expect do
      persister.hardwares.build(hardware_data(1, :vm_or_template => vm_lazy))
    end.to(raise_error(expected_error))
  end

  it "raises exception unless only primary index is used in deep nested lazy_find when building" do
    name = vm_data(1)[:name]
    vm_lazy = persister.vms.lazy_find({:name => name}, :ref => :by_name)
    hardware_lazy = persister.hardwares.lazy_find(:vm_or_template => vm_lazy)

    persister.vms.build(vm_data(1))

    expected_error = "Wrong index for key :hardware, all references under this index must point to default :ref called"\
                     " :manager_ref. Any other :ref is not valid. This applies also to nested lazy links."
    expect do
      persister.disks.build(disk_data(1, :hardware => hardware_lazy))
    end.to(raise_error(expected_error))
  end
end
