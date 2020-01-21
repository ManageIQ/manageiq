module SpecMockedData
  def initialize_mocked_records
    @flavor1 = FactoryBot.create(:flavor, flavor_data(1).merge(:ext_management_system => @ems))
    @flavor2 = FactoryBot.create(:flavor, flavor_data(2).merge(:ext_management_system => @ems))
    @flavor3 = FactoryBot.create(:flavor, flavor_data(3).merge(:ext_management_system => @ems))

    @image1 = FactoryBot.create(:miq_template, image_data(1).merge(:ext_management_system => @ems))
    @image2 = FactoryBot.create(:miq_template, image_data(2).merge(:ext_management_system => @ems))
    @image3 = FactoryBot.create(:miq_template, image_data(3).merge(:ext_management_system => @ems))

    @image_hardware1 = FactoryBot.create(
      :hardware,
      image_hardware_data(1).merge(
        :guest_os       => "linux_generic_1",
        :vm_or_template => @image1
      )
    )
    @image_hardware2 = FactoryBot.create(
      :hardware,
      image_hardware_data(2).merge(
        :guest_os       => "linux_generic_2",
        :vm_or_template => @image2
      )
    )
    @image_hardware3 = FactoryBot.create(
      :hardware,
      image_hardware_data(3).merge(
        :guest_os       => "linux_generic_3",
        :vm_or_template => @image3
      )
    )

    @key_pair1  = FactoryBot.create(:auth_key_pair_cloud, key_pair_data(1).merge(:resource => @ems))
    @key_pair12 = FactoryBot.create(:auth_key_pair_cloud, key_pair_data(12).merge(:resource => @ems))
    @key_pair2  = FactoryBot.create(:auth_key_pair_cloud, key_pair_data(2).merge(:resource => @ems))
    @key_pair3  = FactoryBot.create(:auth_key_pair_cloud, key_pair_data(3).merge(:resource => @ems))

    @vm1 = FactoryBot.create(
      :vm_cloud,
      vm_data(1).merge(
        :flavor                => @flavor_1,
        :genealogy_parent      => @image1,
        :key_pairs             => [@key_pair1],
        :location              => 'host_10_10_10_1.com',
        :ext_management_system => @ems,
      )
    )
    @vm12 = FactoryBot.create(
      :vm_cloud,
      vm_data(12).merge(
        :flavor                => @flavor1,
        :genealogy_parent      => @image1,
        :key_pairs             => [@key_pair1, @key_pair12],
        :location              => 'host_10_10_10_1.com',
        :ext_management_system => @ems,
      )
    )
    @vm2 = FactoryBot.create(
      :vm_cloud,
      vm_data(2).merge(
        :flavor                => @flavor2,
        :genealogy_parent      => @image2,
        :key_pairs             => [@key_pair2],
        :location              => 'host_10_10_10_2.com',
        :ext_management_system => @ems,
      )
    )
    @vm4 = FactoryBot.create(
      :vm_cloud,
      vm_data(4).merge(
        :location              => 'default_value_unknown',
        :ext_management_system => @ems
      )
    )

    @hardware1 = FactoryBot.create(
      :hardware,
      hardware_data(1).merge(
        :guest_os       => @image1.hardware.guest_os,
        :vm_or_template => @vm1
      )
    )
    @hardware12 = FactoryBot.create(
      :hardware,
      hardware_data(12).merge(
        :guest_os       => @image1.hardware.guest_os,
        :vm_or_template => @vm12
      )
    )
    @hardware2 = FactoryBot.create(
      :hardware,
      hardware_data(2).merge(
        :guest_os       => @image2.hardware.guest_os,
        :vm_or_template => @vm2
      )
    )

    @disk1 = FactoryBot.create(
      :disk,
      disk_data(1).merge(
        :hardware => @hardware1,
      )
    )
    @disk12 = FactoryBot.create(
      :disk,
      disk_data(12).merge(
        :hardware => @hardware12,
      )
    )
    @disk13 = FactoryBot.create(
      :disk,
      disk_data(13).merge(
        :hardware => @hardware12,
      )
    )
    @disk2 = FactoryBot.create(
      :disk,
      disk_data(2).merge(
        :hardware => @hardware2,
      )
    )

    @public_network1 = FactoryBot.create(
      :network,
      public_network_data(1).merge(
        :hardware => @hardware1,
      )
    )
    @public_network12 = FactoryBot.create(
      :network,
      public_network_data(12).merge(
        :hardware => @hardware12,
      )
    )
    @public_network13 = FactoryBot.create(
      :network,
      public_network_data(13).merge(
        :hardware    => @hardware12,
        :description => "public_2"
      )
    )
    @public_network2 = FactoryBot.create(
      :network,
      public_network_data(2).merge(
        :hardware => @hardware2,
      )
    )

    @network_port1 = FactoryBot.create(
      :network_port,
      network_port_data(1).merge(
        :device => @vm1
      )
    )

    @network_port12 = FactoryBot.create(
      :network_port,
      network_port_data(12).merge(
        :device => @vm1
      )
    )

    @network_port2 = FactoryBot.create(
      :network_port,
      network_port_data(2).merge(
        :device => @vm2
      )
    )

    @network_port4 = FactoryBot.create(
      :network_port,
      network_port_data(4).merge(
        :device => @vm4
      )
    )

    @orchestration_stack_0_1 = FactoryBot.create(
      :orchestration_stack,
      orchestration_stack_data("0_1").merge(
        :parent => nil
      )
    )

    @orchestration_stack_1_11 = FactoryBot.create(
      :orchestration_stack,
      orchestration_stack_data("1_11").merge(
        :parent => @orchestration_stack_0_1
      )
    )

    @orchestration_stack_1_12 = FactoryBot.create(
      :orchestration_stack,
      orchestration_stack_data("1_12").merge(
        :parent => @orchestration_stack_0_1
      )
    )

    @orchestration_stack_resource_1_11_1 = FactoryBot.create(
      :orchestration_stack_resource,
      orchestration_stack_resource_data("1_11_1").merge(
        :stack => @orchestration_stack_1_11
      )
    )

    @orchestration_stack_resource_1_11_2 = FactoryBot.create(
      :orchestration_stack_resource,
      orchestration_stack_resource_data("1_11_2").merge(
        :stack => @orchestration_stack_1_11
      )
    )

    @orchestration_stack_resource_1_12_1 = FactoryBot.create(
      :orchestration_stack_resource,
      orchestration_stack_resource_data("1_12_1").merge(
        :stack => @orchestration_stack_1_12
      )
    )

    @orchestration_stack_resource_1_12_2 = FactoryBot.create(
      :orchestration_stack_resource,
      orchestration_stack_resource_data("1_12_2").merge(
        :stack => @orchestration_stack_1_12
      )
    )
  end
end
