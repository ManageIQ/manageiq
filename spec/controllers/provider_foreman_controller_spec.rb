describe ProviderForemanController do
  render_views
  before(:each) do
    @zone = EvmSpecHelper.local_miq_server.zone
    tag = Tag.add("/managed/quota_max_memory/2048", :ns => "")

    @provider = ManageIQ::Providers::Foreman::Provider.create(:name => "test", :url => "10.8.96.102", :zone => @zone)
    @config_mgr = ManageIQ::Providers::Foreman::ConfigurationManager.find_by_provider_id(@provider.id)
    @config_profile = ManageIQ::Providers::Foreman::ConfigurationManager::ConfigurationProfile.create(:name                     => "testprofile",
                                                                                                      :description              => "testprofile",
                                                                                                      :configuration_manager_id => @config_mgr.id)
    @config_profile2 = ManageIQ::Providers::Foreman::ConfigurationManager::ConfigurationProfile.create(:name                     => "testprofile2",
                                                                                                       :description              => "testprofile2",
                                                                                                       :configuration_manager_id => @config_mgr.id)
    @configured_system = ManageIQ::Providers::Foreman::ConfigurationManager::ConfiguredSystem.create(:hostname                 => "test_configured_system",
                                                                                                     :configuration_profile_id => @config_profile.id,
                                                                                                     :configuration_manager_id => @config_mgr.id)
    @configured_system2a = ManageIQ::Providers::Foreman::ConfigurationManager::ConfiguredSystem.create(:hostname                 => "test2a_configured_system",
                                                                                                       :configuration_profile_id => @config_profile2.id,
                                                                                                       :configuration_manager_id => @config_mgr.id)
    @configured_system2b = ManageIQ::Providers::Foreman::ConfigurationManager::ConfiguredSystem.create(:hostname                 => "test2b_configured_system",
                                                                                                       :configuration_profile_id => @config_profile2.id,
                                                                                                       :configuration_manager_id => @config_mgr.id)
    @configured_system_unprovisioned =
      ManageIQ::Providers::Foreman::ConfigurationManager::ConfiguredSystem.create(:hostname                 => "configured_system_unprovisioned",
                                                                                  :configuration_profile_id => nil,
                                                                                  :configuration_manager_id => @config_mgr.id)

    @provider2 = ManageIQ::Providers::Foreman::Provider.create(:name => "test2", :url => "10.8.96.103", :zone => @zone)
    @config_mgr2 = ManageIQ::Providers::Foreman::ConfigurationManager.find_by_provider_id(@provider2.id)
    @configured_system_unprovisioned2 =
      ManageIQ::Providers::Foreman::ConfigurationManager::ConfiguredSystem.create(:hostname                 => "configured_system_unprovisioned2",
                                                                                  :configuration_profile_id => nil,
                                                                                  :configuration_manager_id => @config_mgr2.id)
    controller.instance_variable_set(:@sb, :active_tree => :@configuration_manager_providers_tree)

    [@configured_system, @configured_system2a, @configured_system2b, @configured_system_unprovisioned2].each do |cs|
      cs.tag_with(tag, :namespace => '')
    end
  end

  it "renders index" do
    set_user_privileges
    get :index
    expect(response.status).to eq(302)
    expect(response).to redirect_to(:action => 'explorer')
  end

  it "renders explorer" do
    set_user_privileges user_with_feature %w(providers_accord configured_systems_filter_accord)
    set_view_10_per_page

    get :explorer
    accords = controller.instance_variable_get(:@accords)
    expect(accords.size).to eq(2)
    breadcrumbs = controller.instance_variable_get(:@breadcrumbs)
    expect(breadcrumbs[0]).to include(:url => '/provider_foreman/show_list')
    expect(response.status).to eq(200)
    expect(response.body).to_not be_empty
  end

  context "renders explorer based on RBAC" do
    it "renders explorer based on RBAC access to feature 'configured_system_tag'" do
      set_user_privileges user_with_feature %w(configured_system_tag)
      set_view_10_per_page

      get :explorer
      accords = controller.instance_variable_get(:@accords)
      expect(accords.size).to eq(1)
      expect(accords[0][:name]).to eq("cs_filter")
      expect(response.status).to eq(200)
      expect(response.body).to_not be_empty
    end

    it "renders explorer based on RBAC access to feature 'provider_foreman_add_provider'" do
      set_user_privileges user_with_feature %w(provider_foreman_add_provider)
      set_view_10_per_page

      get :explorer
      accords = controller.instance_variable_get(:@accords)
      expect(accords.size).to eq(1)
      expect(accords[0][:name]).to eq("configuration_manager_providers")
      expect(response.status).to eq(200)
      expect(response.body).to_not be_empty
    end
  end

  context "asserts correct privileges" do
    before do
      login_as user_with_feature %w(configured_system_provision)
    end

    it "should not raise an error for feature that user has access to" do
      expect { controller.send(:assert_privileges, "configured_system_provision") }.not_to raise_error
    end

    it "should raise an error for feature that user has access to" do
      expect { controller.send(:assert_privileges, "provider_foreman_add_provider") }
        .to raise_error(MiqException::RbacPrivilegeException)
    end
  end

  it "renders show_list" do
    set_user_privileges
    get :show_list
    expect(response.status).to eq(302)
    expect(response.body).to_not be_empty
  end

  it "renders a new page" do
    set_view_10_per_page
    post :new, :format => :js
    expect(response.status).to eq(200)
  end

  context "#edit" do
    before do
      set_user_privileges
    end

    it "renders the edit page when the configuration manager id is supplied" do
      post :edit, :id => @config_mgr.id
      expect(response.status).to eq(200)
      right_cell_text = controller.instance_variable_get(:@right_cell_text)
      expect(right_cell_text).to eq(_("Edit Foreman Provider"))
    end

    it "renders the edit page when the configuration manager id is selected from a list view" do
      post :edit, :miq_grid_checks => @config_mgr.id
      expect(response.status).to eq(200)
    end

    it "renders the edit page when the configuration manager id is selected from a grid/tile" do
      post :edit, "check_#{ApplicationRecord.compress_id(@config_mgr.id)}" => "1"
      expect(response.status).to eq(200)
    end
  end

  context "renders right cell text" do
    before do
      right_cell_text = nil
      controller.instance_variable_set(:@right_cell_text, right_cell_text)
      controller.send(:build_configuration_manager_tree, :providers, :configuration_manager_providers_tree)

      allow(controller).to receive(:get_view_calculate_gtl_type)
      allow(controller).to receive(:get_view_pages)
      allow(controller).to receive(:build_listnav_search_list)
      allow(controller).to receive(:load_or_clear_adv_search)
      allow(controller).to receive(:replace_search_box)
      allow(controller).to receive(:update_partials)
      allow(controller).to receive(:render)

      controller.instance_variable_set(:@settings, :per_page => {:list => 20})
      allow(controller).to receive(:items_per_page).and_return(20)
      allow(controller).to receive(:gtl_type).and_return("list")
      allow(controller).to receive(:current_page).and_return(1)
      controller.send(:build_configuration_manager_tree, :providers, :configuration_manager_providers_tree)
    end
    it "renders right cell text for root node" do
      key = ems_key_for_provider(@provider)
      controller.send(:get_node_info, key)
      right_cell_text = controller.instance_variable_get(:@right_cell_text)
      expect(right_cell_text).to eq("All #{ui_lookup(:ui_title => "foreman")} Providers")
    end

    it "renders right cell text for ConfigurationManagerForeman node" do
      ems_id = ems_key_for_provider(@provider)
      controller.instance_variable_set(:@_params, :id => ems_id)
      controller.send(:tree_select)
      right_cell_text = controller.instance_variable_get(:@right_cell_text)
      expect(right_cell_text).to eq("Configuration Profiles under Provider \"test Configuration Manager\"")
    end
  end

  it "builds foreman tree" do
    controller.send(:build_configuration_manager_tree, :providers, :configuration_manager_providers_tree)
    first_child = find_treenode_for_provider(@provider)
    expect(first_child["title"]).to eq("test Configuration Manager")
  end

  context "renders tree_select" do
    before do
      right_cell_text = nil
      controller.instance_variable_set(:@right_cell_text, right_cell_text)
      allow(controller).to receive(:get_view_calculate_gtl_type)
      allow(controller).to receive(:get_view_pages)
      allow(controller).to receive(:build_listnav_search_list)
      allow(controller).to receive(:load_or_clear_adv_search)
      allow(controller).to receive(:replace_search_box)
      allow(controller).to receive(:update_partials)
      allow(controller).to receive(:render)

      controller.instance_variable_set(:@settings, :perpage => {:list => 20})
      allow(controller).to receive(:items_per_page).and_return(20)
      allow(controller).to receive(:gtl_type).and_return("list")
      allow(controller).to receive(:current_page).and_return(1)
      controller.send(:build_configuration_manager_tree, :providers, :configuration_manager_providers_tree)
    end
    it "renders the list view based on the nodetype(root,provider,config_profile) and the search associated with it" do
      controller.instance_variable_set(:@_params, :id => "root")
      controller.instance_variable_set(:@search_text, "manager")
      controller.send(:tree_select)
      view = controller.instance_variable_get(:@view)
      expect(view.table.data.size).to eq(2)

      ems_id = ems_key_for_provider(@provider)
      controller.instance_variable_set(:@_params, :id => ems_id)
      controller.send(:tree_select)
      view = controller.instance_variable_get(:@view)
      expect(view.table.data[0].description).to eq("testprofile")

      controller.instance_variable_set(:@search_text, "2")
      controller.send(:tree_select)
      view = controller.instance_variable_get(:@view)
      expect(view.table.data[0].description).to eq("testprofile2")
      config_profile_id2 = config_profile_key(@config_profile2)
      controller.instance_variable_set(:@_params, :id => config_profile_id2)
      controller.send(:tree_select)
      view = controller.instance_variable_get(:@view)
      expect(view.table.data[0].hostname).to eq("test2a_configured_system")

      controller.instance_variable_set(:@search_text, "2b")
      controller.send(:tree_select)
      view = controller.instance_variable_get(:@view)
      expect(view.table.data[0].hostname).to eq("test2b_configured_system")

      allow(controller).to receive(:x_node).and_return("root")
      allow(controller).to receive(:x_tree).and_return(:type => :filter)
      controller.instance_variable_set(:@_params, :id => "cs_filter")
      controller.send(:accordion_select)
      controller.instance_variable_set(:@search_text, "brew")
      allow(controller).to receive(:x_tree).and_return(:type => :providers)
      controller.instance_variable_set(:@_params, :id => "configuration_manager_providers")
      controller.send(:accordion_select)

      controller.instance_variable_set(:@_params, :id => "root")
      controller.send(:tree_select)
      search_text = controller.instance_variable_get(:@search_text)
      expect(search_text).to eq("manager")
      view = controller.instance_variable_get(:@view)
      expect(view.table.data.size).to eq(2)
    end
    it "renders tree_select for a ConfigurationManagerForeman node that contains an unassigned profile" do
      ems_id = ems_key_for_provider(@provider)
      controller.instance_variable_set(:@_params, :id => ems_id)
      controller.send(:tree_select)
      view = controller.instance_variable_get(:@view)
      expect(view.table.data[0].data).to include('description' => "testprofile")
      expect(view.table.data[2]).to include('description' => _("Unassigned Profiles Group"),
                                            'name'        => _("Unassigned Profiles Group"))
    end

    it "renders tree_select for a ConfigurationManagerForeman node that contains only an unassigned profile" do
      ems_id = ems_key_for_provider(@provider2)
      controller.instance_variable_set(:@_params, :id => ems_id)
      controller.send(:tree_select)
      view = controller.instance_variable_get(:@view)
      expect(view.table.data[0]).to include('description' => _("Unassigned Profiles Group"),
                                            'name'        => _("Unassigned Profiles Group"))
    end

    it "renders tree_select for an 'Unassigned Profiles Group' node for the first provider" do
      controller.instance_variable_set(:@_params, :id => "-#{ems_id_for_provider(@provider)}-unassigned")
      controller.send(:tree_select)
      view = controller.instance_variable_get(:@view)
      expect(view.table.data[0].data).to include('hostname' => "configured_system_unprovisioned")
    end

    it "renders tree_select for an 'Unassigned Profiles Group' node for the second provider" do
      controller.instance_variable_set(:@_params, :id => "-#{ems_id_for_provider(@provider2)}-unassigned")
      controller.send(:tree_select)
      view = controller.instance_variable_get(:@view)
      expect(view.table.data[0].data).to include('hostname' => "configured_system_unprovisioned2")
    end
  end

  it "singularizes breadcrumb name" do
    expect(controller.send(:breadcrumb_name, nil)).to eq("#{ui_lookup(:ui_title => "foreman")} Provider")
  end

  it "renders tagging editor" do
    session[:settings] = {:views => {}, :perpage => {:list => 10}}
    session[:tag_items] = [@configured_system.id]
    session[:assigned_filters] = []
    parent = FactoryGirl.create(:classification, :name => "test_category")
    FactoryGirl.create(:classification_tag,      :name => "test_entry",         :parent => parent)
    FactoryGirl.create(:classification_tag,      :name => "another_test_entry", :parent => parent)
    post :tagging, :id => @configured_system.id, :format => :js
    expect(response.status).to eq(200)
  end

  it "renders tree_select as js" do
    controller.send(:build_configuration_manager_tree, :providers, :configuration_manager_providers_tree)

    allow(controller).to receive(:process_show_list)
    allow(controller).to receive(:add_unassigned_configuration_profile_record)
    allow(controller).to receive(:replace_explorer_trees)
    allow(controller).to receive(:build_listnav_search_list)
    allow(controller).to receive(:rebuild_toolbars)
    allow(controller).to receive(:replace_search_box)
    allow(controller).to receive(:update_partials)

    set_user_privileges

    key = ems_key_for_provider(@provider)
    post :tree_select, :id => key, :format => :js
    expect(response.status).to eq(200)
  end

  context "tree_select on provider foreman node" do
    before do
      login_as user_with_feature %w(provider_foreman_refresh_provider provider_foreman_edit_provider provider_foreman_delete_provider)

      allow(controller).to receive(:check_privileges)
      allow(controller).to receive(:process_show_list)
      allow(controller).to receive(:add_unassigned_configuration_profile_record)
      allow(controller).to receive(:replace_explorer_trees)
      allow(controller).to receive(:build_listnav_search_list)
      allow(controller).to receive(:replace_search_box)
      allow(controller).to receive(:x_active_tree).and_return(:configuration_manager_providers_tree)
    end

    it "does not hide Configuration button in the toolbar" do
      controller.send(:build_configuration_manager_tree, :providers, :configuration_manager_providers_tree)
      key = ems_key_for_provider(@provider)
      post :tree_select, :id => key
      expect(response.status).to eq(200)
      expect(response.body).not_to include('<div class=\"hidden btn-group dropdown\"><button data-explorer=\"true\" title=\"Configuration\"')
    end
  end

  context "fetches the list setting:Grid/Tile/List from settings" do
    before do
      allow(controller).to receive(:items_per_page).and_return(20)
      allow(controller).to receive(:current_page).and_return(1)
      allow(controller).to receive(:get_view_pages)
      allow(controller).to receive(:build_listnav_search_list)
      allow(controller).to receive(:load_or_clear_adv_search)
      allow(controller).to receive(:replace_search_box)
      allow(controller).to receive(:update_partials)
      allow(controller).to receive(:render)

      controller.instance_variable_set(:@settings,
                                       :per_page => {:list => 20},
                                       :views    => {:cm_providers          => "grid",
                                                     :cm_configured_systems => "tile"})
      controller.send(:build_configuration_manager_tree, :providers, :configuration_manager_providers_tree)
    end

    it "fetches list type = 'grid' from settings for Providers accordion" do
      key = ems_key_for_provider(@provider)
      allow(controller).to receive(:x_active_accord).and_return(:configuration_manager_providers)
      controller.send(:get_node_info, key)
      list_type = controller.instance_variable_get(:@gtl_type)
      expect(list_type).to eq("grid")
    end

    it "fetches list type = 'tile' from settings for Configured Systems accordion" do
      key = ems_key_for_provider(@provider)
      allow(controller).to receive(:x_active_accord).and_return(:cs_filter)
      controller.send(:get_node_info, key)
      list_type = controller.instance_variable_get(:@gtl_type)
      expect(list_type).to eq("tile")
    end
  end

  context "#build_credentials" do
    it "uses params[:log_password] for validation if one exists" do
      controller.instance_variable_set(:@_params,
                                       :log_userid   => "userid",
                                       :log_password => "password2")
      creds = {:userid => "userid", :password => "password2"}
      expect(controller.send(:build_credentials)).to include(:default => creds)
    end

    it "uses the stored password for validation if params[:log_password] does not exist" do
      controller.instance_variable_set(:@_params, :log_userid => "userid")
      controller.instance_variable_set(:@provider_cfgmgmt, @provider)
      expect(@provider).to receive(:authentication_password).and_return('password')
      creds = {:userid => "userid", :password => "password"}
      expect(controller.send(:build_credentials)).to include(:default => creds)
    end
  end

  context "when user with specific tag settings logs in" do
    before do
      login_as user_with_feature %w(providers_accord configured_systems_filter_accord)
    end
    it "builds foreman tree with no nodes after rbac filtering" do
      user_filters = {'belongs' => [], 'managed' => [["/managed/quota_max_memory/2048"]]}
      allow_any_instance_of(User).to receive(:get_filters).and_return(user_filters)
      controller.send(:build_configuration_manager_tree, :providers, :configuration_manager_providers_tree)
      first_child = find_treenode_for_provider(@provider)
      expect(first_child).to eq(nil)
    end

    it "builds foreman tree with only those nodes that contain the filtered configured systems" do
      user_filters = {'belongs' => [], 'managed' => [["/managed/quota_max_memory/2048"]]}
      allow_any_instance_of(User).to receive(:get_filters).and_return(user_filters)
      Classification.seed
      quota_2gb_tag = Classification.where("description" => "2GB").first
      Classification.bulk_reassignment(:model      => "ConfiguredSystem",
                                       :object_ids => @configured_system.id,
                                       :add_ids    => quota_2gb_tag.id,
                                       :delete_ids => [])
      controller.send(:build_configuration_manager_tree, :providers, :configuration_manager_providers_tree)
      node1 = find_treenode_for_provider(@provider)
      node2 = find_treenode_for_provider(@provider2)
      expect(node1).not_to be_nil
      expect(node2).to be_nil
    end
  end

  def user_with_feature(features)
    features = EvmSpecHelper.specific_product_features(*features)
    FactoryGirl.create(:user, :features => features)
  end

  def set_view_10_per_page
    session[:settings] = {:default_search => '',
                          :views          => {},
                          :perpage        => {:list => 10}}
  end

  def find_treenode_for_provider(provider)
    key =  ems_key_for_provider(provider)
    tree =  JSON.parse(controller.instance_variable_get(:@configuration_manager_providers_tree))
    tree[0]['children'].find { |c| c['key'] == key }
  end

  def ems_key_for_provider(provider)
    ems = ExtManagementSystem.where(:provider_id => provider.id).first
    "e-" + ApplicationRecord.compress_id(ems.id)
  end

  def config_profile_key(config_profile)
    cp = ConfigurationProfile.where(:id => config_profile.id).first
    "cp-" + ApplicationRecord.compress_id(cp.id)
  end

  def ems_id_for_provider(provider)
    ems = ExtManagementSystem.where(:provider_id => provider.id).first
    ems.id
  end
end
