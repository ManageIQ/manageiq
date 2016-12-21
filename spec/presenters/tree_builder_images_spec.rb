describe TreeBuilderImages do
  before do
    @template_cloud_with_az = FactoryGirl.create(:template_cloud,
                                                 :ext_management_system => FactoryGirl.create(:ems_google),
                                                 :storage               => FactoryGirl.create(:storage))

    login_as FactoryGirl.create(:user_with_group, :role => "operator", :settings => {})

    allow(MiqServer).to receive(:my_server) { FactoryGirl.create(:miq_server) }

    @images_tree = TreeBuilderImages.new(:images, :images_tree, {}, nil)
  end

  it 'sets tree to have leaf and not lazy' do
    root_options = @images_tree.tree_init_options(nil)
    expect(root_options).to eq(:leaf => "ManageIQ::Providers::CloudManager::Template")
  end

  it 'sets tree to have full ids, not lazy and no root' do
    locals = @images_tree.set_locals_for_render
    expect(locals[:tree_id]).to eq("images_treebox")
    expect(locals[:tree_name]).to eq("images_tree")
    expect(locals[:autoload]).to eq(true)
  end

  it 'sets root correctly' do
    root = @images_tree.root_options
    expect(root).to eq(["Images by Provider", "All Images by Provider that I can see"])
  end

  it 'sets providers nodes correctly' do
    providers = @images_tree.x_get_tree_roots(false, nil)
    expect(providers).to eq([@template_cloud_with_az.ext_management_system,
                             {:id    => "arch",
                              :text  => "<Archived>",
                              :image => "100/currentstate-archived.png",
                              :tip   => "Archived Images"},
                             {:id    => "orph",
                              :text  => "<Orphaned>",
                              :image => "100/currentstate-orphaned.png",
                              :tip   => "Orphaned Images"}])
  end

  it 'sets Templates nodes to empty Array if VMs/Templates are hidden' do
    User.current_user.settings[:display] = {:display_vms => false}

    provider = @images_tree.x_get_tree_roots(false, nil)[0]
    template = @images_tree.x_get_tree_ems_kids(provider, false)
    expect(template).to eq([])
  end

  it 'sets Templates nodes correctly if VMs/Templates are shown' do
    User.current_user.settings[:display] = {:display_vms => true}
    provider = @images_tree.x_get_tree_roots(false, nil)[0]
    template = @images_tree.x_get_tree_ems_kids(provider, false)
    expect(template).to eq([@template_cloud_with_az])
  end
end
