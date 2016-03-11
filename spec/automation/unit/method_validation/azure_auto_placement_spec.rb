describe "azure best fit" do
  let(:cloud_network)     { FactoryGirl.create(:cloud_network, :ems_id => ems.id, :enabled => true) }
  let(:cloud_subnet)      { FactoryGirl.create(:cloud_subnet, :cloud_network_id => cloud_network.id) }
  let(:ems)               { FactoryGirl.create(:ems_azure_with_authentication) }
  let(:m2_small_flavor)   { FactoryGirl.create(:flavor_azure, :ems_id => ems.id, :cloud_subnet_required => false) }
  let(:miq_provision)     do
    FactoryGirl.create(:miq_provision_azure,
                       :options => options,
                       :userid  => user.userid,
                       :state   => 'active',
                       :status  => 'Ok')
  end
  let(:options) do
    {:src_vm_id      => vm_template.id,
     :placement_auto => [true, 1],
     :instance_type  => [m2_small_flavor.id, m2_small_flavor.name]}
  end
  let(:resource_group)    { FactoryGirl.create(:resource_group, :ems_id => ems.id) }
  let(:user)              { FactoryGirl.create(:user_with_group) }
  let(:vm_template)       { FactoryGirl.create(:template_azure, :ext_management_system => ems) }
  let(:ws) do
    MiqAeEngine.instantiate("/System/Request/Call_Instance_With_Message?" \
                            "namespace=Cloud/VM/Provisioning&class=Placement" \
                            "&instance=default&message=azure&" \
                            "MiqProvision::miq_provision=#{miq_provision.id}", user)
  end

  it "provision task object auto placement for cloud network" do
    MiqServer.seed
    cloud_subnet
    resource_group
    ws.root

    expect(miq_provision.reload.options).to have_attributes(
      :cloud_network  => [cloud_network.id,  cloud_network.name],
      :cloud_subnet   => [cloud_subnet.id,   cloud_subnet.name],
      :resource_group => [resource_group.id, resource_group.name],
    )
  end
end
