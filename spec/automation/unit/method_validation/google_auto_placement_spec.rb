describe "GOOGLE best fit" do
  let(:availability_zone) { FactoryGirl.create(:availability_zone_google) }
  let(:cloud_network)     { FactoryGirl.create(:cloud_network, :ems_id => ems.id, :enabled => true) }
  let(:cloud_subnet)      { FactoryGirl.create(:cloud_subnet, :cloud_network_id => cloud_network.id) }
  let(:ems)               do
    FactoryGirl.create(:ems_google_with_authentication,
                       :availability_zones => [availability_zone])
  end
  let(:m2_small_flavor)   { FactoryGirl.create(:flavor_google, :ems_id => ems.id, :cloud_subnet_required => false) }
  let(:miq_provision)     do
    FactoryGirl.create(:miq_provision_google,
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
  let(:user)              { FactoryGirl.create(:user_with_group) }
  let(:vm_template)       { FactoryGirl.create(:template_google, :ext_management_system => ems) }

  let(:ws) do
    MiqAeEngine.instantiate("/System/Request/Call_Instance_With_Message?" \
                            "namespace=Cloud/VM/Provisioning&class=Placement" \
                            "&instance=default&message=google&" \
                            "MiqProvision::miq_provision=#{miq_provision.id}", user)
  end

  it "provision task object auto placement for cloud network" do
    MiqServer.seed
    cloud_subnet
    ws.root

    expect(miq_provision.reload.options).to have_attributes(
      :cloud_network               => [cloud_network.id, cloud_network.name],
      :placement_availability_zone => [availability_zone.id, availability_zone.name]
    )
  end
end
