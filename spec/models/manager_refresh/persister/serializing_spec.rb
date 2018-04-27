require_relative '../helpers/spec_parsed_data'
require_relative 'test_persister'
require_relative 'targeted_refresh_spec_helper'

describe ManagerRefresh::Inventory::Persister do
  include SpecParsedData
  include TargetedRefreshSpecHelper

  ######################################################################################################################
  # Spec scenarios testing Perister can serialize/deserialize, with having complex nested lazy_find links
  ######################################################################################################################
  #
  before :each do
    @zone = FactoryGirl.create(:zone)
    @ems  = FactoryGirl.create(:ems_cloud,
                               :zone            => @zone,
                               :network_manager => FactoryGirl.create(:ems_network, :zone => @zone))

    allow(@ems.class).to receive(:ems_type).and_return(:mock)
    allow(Settings.ems_refresh).to receive(:mock).and_return({})
  end

  let(:persister) { create_persister }

  it "tests we can serialize inventory object with nested lazy references" do
    persister = create_persister
    populate_test_data(persister)

    ManagerRefresh::Inventory::Persister.from_json(persister.to_json).persist!

    counts = {
      :disk           => 2,
      :flavor         => 0,
      :hardware       => 3,
      :miq_template   => 1,
      :network        => 2,
      :vm             => 2,
      :vm_or_template => 3
    }

    assert_counts(counts)

    vm = Vm.find_by(:ems_ref => "vm_ems_ref_1")
    expect(vm.location).to eq("host_10_10_10_1.com")
    expect(vm.hardware.guest_os).to eq("linux_generic_1")
    expect(vm.hardware.guest_os_full_name).to eq("amazon")
    expect(vm.hardware.networks.first.ipaddress).to eq("10.10.10.1")
    expect(vm.hardware.disks.first.device_name).to eq("disk_name_1")

    vm2 = Vm.find_by(:ems_ref => "vm_ems_ref_2")
    expect(vm2.hardware.networks.first.ipaddress).to eq("10.10.10.2")
    expect(vm2.hardware.disks.first.device_name).to eq("disk_name_2")

    # TODO(lsmola) interestingly persister.hardwares.lazy_find({:vm_or_template => lazy_find_image_sec}) will not work
    # because we build the reference only from the passed data. To make it work, we would have to do internally
    # persister.hardwares.lazy_find({:vm_or_template => lazy_find_image_sec.load}), which will allow the nested lazy
    # find to reach its :manager_ref data. That would mean the stringified reference would have to be build when
    # we try to evaluate the lazy object. We should be able to do that.
    expect(vm.hardware.model).to eq(nil)
    expect(vm.hardware.manufacturer).to eq(nil)
  end

  def populate_test_data(persister)
    @image_data_1          = image_data(1)
    @image_hardware_data_1 = image_hardware_data(1).merge(
      :guest_os       => "linux_generic_1",
      :vm_or_template => persister.miq_templates.lazy_find(:ems_ref => image_data(1)[:ems_ref]),
      :model          => "test1",
      :manufacturer   => "test2"
    )

    # Nested lazy find
    lazy_find_image      = persister.miq_templates.lazy_find(:ems_ref => image_data(1)[:ems_ref])
    lazy_find_image_sec  = persister.miq_templates.lazy_find({:name => image_data(1)[:name]}, {:ref => :by_name})
    lazy_find_image_sec1 = persister.miq_templates.lazy_find(
      {:name => image_data(1)[:name], :uid_ems => image_data(1)[:uid_ems]}, {:ref => :by_uid_ems_and_name}
    )
    lazy_find_image_sec2 = persister.miq_templates.lazy_find(
      {:name => image_data(1)[:name], :uid_ems => image_data(1)[:uid_ems]}, {:ref => :by_uid_ems_and_name, :key => :vendor}
    )
    lazy_find_vm         = persister.vms.lazy_find(:ems_ref => vm_data(1)[:ems_ref])
    lazy_find_hardware   = persister.hardwares.lazy_find(:vm_or_template => lazy_find_vm)

    @vm_data_1 = vm_data(1).merge(
      :flavor           => persister.flavors.lazy_find(:ems_ref => flavor_data(1)[:name]),
      :genealogy_parent => persister.miq_templates.lazy_find(:ems_ref => image_data(1)[:ems_ref]),
      :key_pairs        => [persister.key_pairs.lazy_find(:name => key_pair_data(1)[:name])],
      :location         => persister.networks.lazy_find(
        {:hardware => lazy_find_hardware, :description => "public"},
        {:key     => :hostname,
         :default => 'default_value_unknown'}
      ),
    )

    @hardware_data_1 = hardware_data(1).merge(
      :guest_os           => persister.hardwares.lazy_find({:vm_or_template => lazy_find_image}, {:key => :guest_os}),
      :model              => persister.hardwares.lazy_find({:vm_or_template => lazy_find_image_sec}, {:key => :model}),
      :manufacturer       => persister.hardwares.lazy_find({:vm_or_template => lazy_find_image_sec1}, {:key => :manufacturer}),
      :guest_os_full_name => lazy_find_image_sec2,
      :vm_or_template     => persister.vms.lazy_find(:ems_ref => vm_data(1)[:ems_ref])
    )

    @public_network_data_1 = public_network_data(1).merge(
      :hardware => persister.hardwares.lazy_find(:vm_or_template => lazy_find_vm),
    )

    @disk_data_1 = disk_data(1).merge(
      :hardware => persister.hardwares.lazy_find(:vm_or_template => lazy_find_vm),
    )

    persister.miq_templates.build(@image_data_1)
    persister.hardwares.build(@image_hardware_data_1)
    persister.vms.build(@vm_data_1)
    persister.hardwares.build(@hardware_data_1)
    persister.networks.build(@public_network_data_1)
    persister.disks.build(@disk_data_1)

    # Try also data with relations without lazy link
    vm       = persister.vms.build(vm_data(2))
    hardware = persister.hardwares.build(hardware_data(2).merge(:vm_or_template => vm))
    persister.networks.build(public_network_data(2).merge(:hardware => hardware))
    persister.disks.build(disk_data(2).merge(:hardware => hardware))
  end
end
