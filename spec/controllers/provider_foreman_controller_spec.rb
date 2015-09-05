require "spec_helper"

describe ProviderForemanController do
  render_views
  before(:each) do
    _, @server, @zone = EvmSpecHelper.create_guid_miq_server_zone

    @provider = ManageIQ::Providers::Foreman::Provider.create(:name => "test", :url => "10.8.96.102", :zone => @zone)
    @config_mgr = ManageIQ::Providers::Foreman::ConfigurationManager.find_by_provider_id(@provider.id)
    @config_profile = ManageIQ::Providers::Foreman::ConfigurationManager::ConfigurationProfile.create(:name                     => "testprofile",
                                                                                                      :description              => "testprofile",
                                                                                                      :configuration_manager_id => @config_mgr.id)
    @configured_system = ManageIQ::Providers::Foreman::ConfigurationManager::ConfiguredSystem.create(:hostname                 => "test_configured_system",
                                                                                                     :configuration_profile_id => @config_profile.id,
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
    controller.instance_variable_set(:@sb, :active_tree => :foreman_providers_tree)
  end

  it "renders index" do
    set_user_privileges
    get :index
    expect(response.status).to eq(302)
    response.should redirect_to(:action => 'explorer')
  end

  it "renders explorer" do
    set_user_privileges user_with_feature %w(providers_accord configured_systems_filter_accord)
    set_view_10_per_page

    get :explorer
    accords = controller.instance_variable_get(:@accords)
    expect(accords.size).to eq(2)
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
      expect(accords[0][:name]).to eq("foreman_providers")
      expect(response.status).to eq(200)
      expect(response.body).to_not be_empty
    end
  end

  context "asserts correct privileges" do
    before do
      login_as user_with_feature %w(configured_system_provision)
    end

    it "should not raise an error for feature that user has access to" do
      lambda do
        controller.send(:assert_privileges, "configured_system_provision")
      end.should_not raise_error
    end

    it "should raise an error for feature that user has access to" do
      lambda do
        controller.send(:assert_privileges, "provider_foreman_add_provider")
      end.should raise_error
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

  context "renders right cell text" do
    before do
      right_cell_text = nil
      controller.instance_variable_set(:@right_cell_text, right_cell_text)
      controller.send(:build_foreman_tree, :providers, :foreman_providers_tree)

      controller.stub(:get_view_calculate_gtl_type)
      controller.stub(:get_view_pages)
      controller.stub(:build_listnav_search_list)
      controller.stub(:load_or_clear_adv_search)
      controller.stub(:replace_search_box)
      controller.stub(:update_partials)
      controller.stub(:render)

      controller.instance_variable_set(:@settings, :per_page => {:list => 20})
      controller.stub(:items_per_page).and_return(20)
      controller.stub(:gtl_type).and_return("list")
      controller.stub(:current_page).and_return(1)
      controller.send(:build_foreman_tree, :providers, :foreman_providers_tree)
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
    controller.send(:build_foreman_tree, :providers, :foreman_providers_tree)
    first_child = find_treenode_for_provider(@provider)
    expect(first_child["title"]).to eq("test Configuration Manager")
  end

  context "renders tree_select" do
    before do
      right_cell_text = nil
      controller.instance_variable_set(:@right_cell_text, right_cell_text)
      controller.stub(:get_view_calculate_gtl_type)
      controller.stub(:get_view_pages)
      controller.stub(:build_listnav_search_list)
      controller.stub(:load_or_clear_adv_search)
      controller.stub(:replace_search_box)
      controller.stub(:update_partials)
      controller.stub(:render)

      controller.instance_variable_set(:@settings, :perpage => {:list => 20})
      controller.stub(:items_per_page).and_return(20)
      controller.stub(:gtl_type).and_return("list")
      controller.stub(:current_page).and_return(1)
      controller.send(:build_foreman_tree, :providers, :foreman_providers_tree)
    end
    it "renders tree_select for a ConfigurationManagerForeman node that contains an unassigned profile" do
      ems_id = ems_key_for_provider(@provider)
      controller.instance_variable_set(:@_params, :id => ems_id)
      controller.send(:tree_select)
      view = controller.instance_variable_get(:@view)
      expect(view.table.data[0].data).to include('description' => "testprofile")
      expect(view.table.data[1]).to include('description' => _("Unassigned Profiles Group"),
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
    controller.send(:build_foreman_tree, :providers, :foreman_providers_tree)

    controller.stub(:process_show_list)
    controller.stub(:add_unassigned_configuration_profile_record)
    controller.stub(:replace_explorer_trees)
    controller.stub(:build_listnav_search_list)
    controller.stub(:rebuild_toolbars)
    controller.stub(:replace_search_box)
    controller.stub(:update_partials)

    set_user_privileges

    key = ems_key_for_provider(@provider)
    post :tree_select, :id => key, :format => :js
    expect(response.status).to eq(200)
  end

  context "fetches the list setting:Grid/Tile/List from settings" do
    before do
      controller.stub(:items_per_page).and_return(20)
      controller.stub(:current_page).and_return(1)
      controller.stub(:get_view_pages)
      controller.stub(:build_listnav_search_list)
      controller.stub(:load_or_clear_adv_search)
      controller.stub(:replace_search_box)
      controller.stub(:update_partials)
      controller.stub(:render)

      controller.instance_variable_set(:@settings,
                                       :per_page => {:list => 20},
                                       :views    => {:cm_providers          => "grid",
                                                     :cm_configured_systems => "tile"})
      controller.send(:build_foreman_tree, :providers, :foreman_providers_tree)
    end

    it "fetches list type = 'grid' from settings for Providers accordion" do
      key = ems_key_for_provider(@provider)
      controller.stub(:x_active_accord).and_return(:foreman_providers)
      controller.send(:get_node_info, key)
      list_type = controller.instance_variable_get(:@gtl_type)
      expect(list_type).to eq("grid")
    end

    it "fetches list type = 'tile' from settings for Configured Systems accordion" do
      key = ems_key_for_provider(@provider)
      controller.stub(:x_active_accord).and_return(:cs_filter)
      controller.send(:get_node_info, key)
      list_type = controller.instance_variable_get(:@gtl_type)
      expect(list_type).to eq("tile")
    end
  end

  def user_with_feature(features)
    EvmSpecHelper.seed_specific_product_features(*features)
    feature = MiqProductFeature.find_all_by_identifier(features)
    test_user_role  = FactoryGirl.create(:miq_user_role,
                                         :name                 => "test_user_role",
                                         :miq_product_features => feature)
    test_user_group = FactoryGirl.create(:miq_group, :miq_user_role => test_user_role)
    FactoryGirl.create(:user, :userid => 'test_user', :name => 'test_user', :miq_groups => [test_user_group])
  end

  def set_view_10_per_page
    session[:settings] = {:default_search => '',
                          :views          => {},
                          :perpage        => {:list => 10}}
  end

  def find_treenode_for_provider(provider)
    key =  ems_key_for_provider(provider)
    tree =  JSON.parse(controller.instance_variable_get(:@foreman_providers_tree))
    tree[0]['children'].find { |c| c['key'] == key }
  end

  def ems_key_for_provider(provider)
    ems = ExtManagementSystem.where(:provider_id => provider.id).first
    "e-" + ActiveRecord::Base.compress_id(ems.id)
  end

  def ems_id_for_provider(provider)
    ems = ExtManagementSystem.where(:provider_id => provider.id).first
    ems.id
  end
end
