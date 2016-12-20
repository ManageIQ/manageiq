describe TreeBuilderInstances do
  before do
    @vm_cloud_with_az = FactoryGirl.create(:vm_cloud,
                                           :ext_management_system => FactoryGirl.create(:ems_google),
                                           :storage               => FactoryGirl.create(:storage),
                                           :availability_zone     => FactoryGirl.create(:availability_zone_google))
    @vm_cloud_without_az = FactoryGirl.create(:vm_cloud,
                                              :ext_management_system => FactoryGirl.create(:ems_google),
                                              :storage               => FactoryGirl.create(:storage),)

    login_as FactoryGirl.create(:user_with_group, :role => "operator", :settings => {})

    allow(MiqServer).to receive(:my_server) { FactoryGirl.create(:miq_server) }

    @instances_tree = TreeBuilderInstances.new(:instances, :instances_tree, {}, nil)
  end

  it 'sets tree to have leaf and not lazy' do
    root_options = @instances_tree.tree_init_options(nil)

    expect(root_options).to eq(:leaf => 'VmCloud', :lazy => false)
  end

  it 'sets tree to have full ids, not lazy and no root' do
    locals = @instances_tree.set_locals_for_render

    expect(locals[:tree_id]).to eq("instances_treebox")
    expect(locals[:tree_name]).to eq("instances_tree")
    expect(locals[:autoload]).to eq(true)
  end

  it 'sets root correctly' do
    root = @instances_tree.root_options

    expect(root).to eq(["Instances by Provider", "All Instances by Provider that I can see"])
  end

  it 'sets providers nodes correctly' do
    providers = @instances_tree.x_get_tree_roots(false, nil)

    expect(providers).to eq([@vm_cloud_with_az.ext_management_system,
                             @vm_cloud_without_az.ext_management_system,
                             {:id    => "arch",
                              :text  => "<Archived>",
                              :image => "100/currentstate-archived.png",
                              :tip   => "Archived Instances"},
                             {:id    => "orph",
                              :text  => "<Orphaned>",
                              :image => "100/currentstate-orphaned.png",
                              :tip   => "Orphaned Instances"}])
  end

  it 'sets availability zones correctly if vms are hidden' do
    User.current_user.settings[:display] = {:display_vms => false}

    provider_with_az = @instances_tree.x_get_tree_roots(false, nil)[0] # provider with vm that has availability zone
    provider_without_az = @instances_tree.x_get_tree_roots(false, nil)[1] # provider with vm that doesn't have availability zone
    allow(provider_with_az).to receive(:availability_zones) { [@vm_cloud_with_az.availability_zone] }
    az = @instances_tree.x_get_tree_ems_kids(provider_with_az, false)
    vm_without_az = @instances_tree.x_get_tree_ems_kids(provider_without_az, false)

    expect(az).to eq(provider_with_az.availability_zones)
    expect(vm_without_az).to eq([])
  end

  it 'sets availability zones correctly if vms are shown' do
    User.current_user.settings[:display] = {:display_vms => true}

    provider_with_az = @instances_tree.x_get_tree_roots(false, nil)[0] # provider with vm that has availability zone
    provider_without_az = @instances_tree.x_get_tree_roots(false, nil)[1] # provider with vm that doesn't have availability zone
    allow(provider_with_az).to receive(:availability_zones) { [@vm_cloud_with_az.availability_zone] }
    az = @instances_tree.x_get_tree_ems_kids(provider_with_az, false)
    vm_without_az = @instances_tree.x_get_tree_ems_kids(provider_without_az, false)

    expect(az).to eq([@vm_cloud_with_az.availability_zone])
    expect(vm_without_az).to eq([@vm_cloud_without_az])
  end
end
