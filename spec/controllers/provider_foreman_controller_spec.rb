describe ProviderForemanController do
  render_views

  let(:tags) { ["/managed/quota_max_memory/2048"] }
  before(:each) do
    @zone = EvmSpecHelper.local_miq_server.zone
    Tag.find_or_create_by(:name => tags.first)

    @provider = ManageIQ::Providers::Foreman::Provider.create(:name => "testForeman", :url => "10.8.96.102", :zone => @zone)
    @config_mgr = ManageIQ::Providers::Foreman::ConfigurationManager.find_by_provider_id(@provider.id)
    @config_profile = ManageIQ::Providers::Foreman::ConfigurationManager::ConfigurationProfile.create(:name        => "testprofile",
                                                                                                      :description => "testprofile",
                                                                                                      :manager_id  => @config_mgr.id)
    @config_profile2 = ManageIQ::Providers::Foreman::ConfigurationManager::ConfigurationProfile.create(:name        => "testprofile2",
                                                                                                       :description => "testprofile2",
                                                                                                       :manager_id  => @config_mgr.id)
    @configured_system = ManageIQ::Providers::Foreman::ConfigurationManager::ConfiguredSystem.create(:hostname                 => "test_configured_system",
                                                                                                     :configuration_profile_id => @config_profile.id,
                                                                                                     :manager_id               => @config_mgr.id)
    @configured_system2a = ManageIQ::Providers::Foreman::ConfigurationManager::ConfiguredSystem.create(:hostname                 => "test2a_configured_system",
                                                                                                       :configuration_profile_id => @config_profile2.id,
                                                                                                       :manager_id               => @config_mgr.id)
    @configured_system2b = ManageIQ::Providers::Foreman::ConfigurationManager::ConfiguredSystem.create(:hostname                 => "test2b_configured_system",
                                                                                                       :configuration_profile_id => @config_profile2.id,
                                                                                                       :manager_id               => @config_mgr.id)
    @configured_system_unprovisioned =
      ManageIQ::Providers::Foreman::ConfigurationManager::ConfiguredSystem.create(:hostname                 => "configured_system_unprovisioned",
                                                                                  :configuration_profile_id => nil,
                                                                                  :manager_id               => @config_mgr.id)

    @provider2 = ManageIQ::Providers::Foreman::Provider.create(:name => "test2Foreman", :url => "10.8.96.103", :zone => @zone)
    @config_mgr2 = ManageIQ::Providers::Foreman::ConfigurationManager.find_by_provider_id(@provider2.id)
    @configured_system_unprovisioned2 =
      ManageIQ::Providers::Foreman::ConfigurationManager::ConfiguredSystem.create(:hostname                 => "configured_system_unprovisioned2",
                                                                                  :configuration_profile_id => nil,
                                                                                  :manager_id               => @config_mgr2.id)
    controller.instance_variable_set(:@sb, :active_tree => :configuration_manager_providers_tree)

    [@configured_system, @configured_system2a, @configured_system2b, @configured_system_unprovisioned2].each do |cs|
      cs.tag_with(tags, :namespace => '')
    end

    @provider_ans = ManageIQ::Providers::AnsibleTower::Provider.create(:name => "ansibletest", :url => "10.8.96.108", :zone => @zone)
    @config_ans = ManageIQ::Providers::AnsibleTower::ConfigurationManager.find_by_provider_id(@provider_ans.id)

    @provider_ans2 = ManageIQ::Providers::AnsibleTower::Provider.create(:name => "ansibletest2", :url => "10.8.96.109", :zone => @zone)
    @config_ans2 = ManageIQ::Providers::AnsibleTower::ConfigurationManager.find_by_provider_id(@provider_ans2.id)

    @inventory_group = ManageIQ::Providers::ConfigurationManager::InventoryRootGroup.create(:name => "testinvgroup", :ems_id => @config_ans.id)
    @inventory_group2 = ManageIQ::Providers::ConfigurationManager::InventoryRootGroup.create(:name => "testinvgroup2", :ems_id => @config_ans2.id)
    @ans_configured_system = ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfiguredSystem.create(:hostname                => "ans_test_configured_system",
                                                                                                              :inventory_root_group_id => @inventory_group.id,
                                                                                                              :manager_id              => @config_ans.id)

    @ans_configured_system2a = ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfiguredSystem.create(:hostname                => "test2a_ans_configured_system",
                                                                                                                :inventory_root_group_id => @inventory_group.id,
                                                                                                                :manager_id              => @config_ans.id)
    @ans_configured_system2b = ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfiguredSystem.create(:hostname                => "test2b_ans_configured_system",
                                                                                                                :inventory_root_group_id => @inventory_group2.id,
                                                                                                                :manager_id              => @config_ans2.id)
    @ans_job_template1 = FactoryGirl.create(:ansible_configuration_script, :name => "ConfigScript1", :manager_id => @config_ans.id)
    @ans_job_template2 = FactoryGirl.create(:ansible_configuration_script, :name => "ConfigScript2", :manager_id => @config_ans2.id)
    @ans_job_template3 = FactoryGirl.create(:ansible_configuration_script, :name => "ConfigScript3", :manager_id => @config_ans.id)
  end

  it "renders index" do
    stub_user(:features => :all)
    get :index
    expect(response.status).to eq(302)
    expect(response).to redirect_to(:action => 'explorer')
  end

  it "renders explorer" do
    login_as user_with_feature(%w(providers_accord configured_systems_filter_accord configuration_scripts_accord))

    get :explorer
    accords = controller.instance_variable_get(:@accords)
    expect(accords.size).to eq(3)
    breadcrumbs = controller.instance_variable_get(:@breadcrumbs)
    expect(breadcrumbs[0]).to include(:url => '/provider_foreman/show_list')
    expect(response.status).to eq(200)
    expect(response.body).to_not be_empty
  end

  context "renders explorer based on RBAC" do
    it "renders explorer based on RBAC access to feature 'configured_system_tag'" do
      login_as user_with_feature %w(configured_system_tag)

      get :explorer
      accords = controller.instance_variable_get(:@accords)
      expect(accords.size).to eq(1)
      expect(accords[0][:name]).to eq("cs_filter")
      expect(response.status).to eq(200)
      expect(response.body).to_not be_empty
    end

    it "renders explorer based on RBAC access to feature 'provider_foreman_add_provider'" do
      login_as user_with_feature %w(provider_foreman_add_provider)

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
    stub_user(:features => :all)
    get :show_list
    expect(response.status).to eq(302)
    expect(response.body).to_not be_empty
  end

  it "renders a new page" do
    post :new, :format => :js
    expect(response.status).to eq(200)
  end

  context "Verify the provisionable flag for CSs" do
    it "Provision action should be allowed for a Configured System marked as provisionable" do
      allow(controller).to receive(:x_node).and_return("root")
      allow(controller).to receive(:x_tree).and_return(:type => :filter)
      controller.instance_variable_set(:@_params, :id => "cs_filter")
      allow(controller).to receive(:replace_right_cell)
      controller.instance_variable_set(:@_params, :id => @config_ans2.id)
      controller.send(:provision)
      expect(controller.send(:flash_errors?)).to be_truthy
      expect(assigns(:flash_array).first[:message]).to include("Provisioning is not supported for at least one of the selected systems")
    end

    it "Provision action should not be allowed only for a Configured System marked as not provisionable" do
      allow(controller).to receive(:x_node).and_return("root")
      allow(controller).to receive(:x_tree).and_return(:type => :filter)
      controller.instance_variable_set(:@_params, :id => "cs_filter")
      allow(controller).to receive(:replace_right_cell)
      allow(controller).to receive(:render)
      controller.instance_variable_set(:@_params, :id => @configured_system2a.id)
      controller.send(:provision)
      expect(controller.send(:flash_errors?)).to_not be_truthy
    end
  end

  it "#save_provider_foreman will not save with a duplicate name" do
    ManageIQ::Providers::Foreman::Provider.create(:name => "test2Foreman", :url => "server1", :zone => @zone)
    provider2 = ManageIQ::Providers::Foreman::Provider.new(:name => "test2Foreman", :url => "server2", :zone => @zone)
    controller.instance_variable_set(:@provider_cfgmgmt, provider2)
    allow(controller).to receive(:render_flash)
    controller.save_provider_foreman
    expect(assigns(:flash_array).first[:message]).to include("Name has already been taken")
  end

  context "#edit" do
    before do
      stub_user(:features => :all)
    end

    it "renders the edit page when the configuration manager id is supplied" do
      post :edit, :params => { :id => @config_mgr.id }
      expect(response.status).to eq(200)
      right_cell_text = controller.instance_variable_get(:@right_cell_text)
      expect(right_cell_text).to eq(_("Edit Configuration Manager Provider"))
    end

    it "should display the zone field" do
      new_zone = FactoryGirl.create(:zone, :name => "TestZone")
      controller.instance_variable_set(:@provider_cfgmgmt, @provider)
      post :edit, :params => { :id => @config_mgr.id }
      expect(response.status).to eq(200)
      expect(response.body).to include("option value=\\\"#{new_zone.name}\\\"")
    end

    it "should save the zone field" do
      new_zone = FactoryGirl.create(:zone, :name => "TestZone")
      controller.instance_variable_set(:@provider_cfgmgmt, @provider)
      allow(controller).to receive(:leaf_record).and_return(false)
      post :edit, :params => { :button     => 'save',
                               :id         => @config_mgr.id,
                               :zone       => new_zone.name,
                               :url        => @provider.url,
                               :verify_ssl => @provider.verify_ssl }
      expect(response.status).to eq(200)
      expect(@provider.zone).to eq(new_zone)
    end

    it "renders the edit page when the configuration manager id is selected from a list view" do
      post :edit, :params => { :miq_grid_checks => @config_mgr.id }
      expect(response.status).to eq(200)
    end

    it "renders the edit page when the configuration manager id is selected from a grid/tile" do
      post :edit, :params => { "check_#{ApplicationRecord.compress_id(@config_mgr.id)}" => "1" }
      expect(response.status).to eq(200)
    end
  end

  context "#refresh" do
    before do
      stub_user(:features => :all)
      allow(controller).to receive(:x_node).and_return("root")
      allow(controller).to receive(:rebuild_toolbars).and_return("true")
    end

    it "renders the refresh flash message for Ansible Tower" do
      post :refresh, :params => {:miq_grid_checks => @config_ans.id}
      expect(response.status).to eq(200)
      expect(assigns(:flash_array).first[:message]).to include("Refresh Provider initiated for 1 provider (Ansible Tower)")
    end

    it "renders the refresh flash message for Foreman" do
      post :refresh, :params => {:miq_grid_checks => @config_mgr.id}
      expect(response.status).to eq(200)
      expect(assigns(:flash_array).first[:message]).to include("Refresh Provider initiated for 1 provider (Foreman)")
    end

    it "refreshes the provider when the configuration manager id is supplied" do
      allow(controller).to receive(:replace_right_cell)
      post :refresh, :params => { :id => @config_mgr.id }
      expect(assigns(:flash_array).first[:message]).to include("Refresh Provider initiated for 1 provider")
    end

    it "it refreshes a provider when the configuration manager id is selected from a grid/tile" do
      allow(controller).to receive(:replace_right_cell)
      post :refresh, :params => { "check_#{ApplicationRecord.compress_id(@config_mgr.id)}"  => "1",
                                  "check_#{ApplicationRecord.compress_id(@config_mgr2.id)}" => "1" }
      expect(assigns(:flash_array).first[:message]).to include("Refresh Provider initiated for 2 providers")
    end
  end

  context "#delete" do
    before do
      stub_user(:features => :all)
    end

    it "deletes the provider when the configuration manager id is supplied" do
      allow(controller).to receive(:replace_right_cell)
      post :delete, :params => { :id => @config_mgr.id }
      expect(assigns(:flash_array).first[:message]).to include("Delete initiated for 1 Provider")
    end

    it "it deletes a provider when the configuration manager id is selected from a list view" do
      allow(controller).to receive(:replace_right_cell)
      post :delete, :params => { :miq_grid_checks => "#{@config_mgr.id}, #{@config_mgr2.id}"}
      expect(assigns(:flash_array).first[:message]).to include("Delete initiated for 2 Providers")
    end

    it "it deletes a provider when the configuration manager id is selected from a grid/tile" do
      allow(controller).to receive(:replace_right_cell)
      post :delete, :params => { "check_#{ApplicationRecord.compress_id(@config_mgr.id)}" => "1" }
      expect(assigns(:flash_array).first[:message]).to include("Delete initiated for 1 Provider")
    end
  end

  context "renders right cell text" do
    before do
      right_cell_text = nil
      login_as user_with_feature(%w(providers_accord configured_systems_filter_accord configuration_scripts_accord))
      controller.instance_variable_set(:@right_cell_text, right_cell_text)
      allow(controller).to receive(:get_view_calculate_gtl_type)
      allow(controller).to receive(:get_view_pages)
      allow(controller).to receive(:build_listnav_search_list)
      allow(controller).to receive(:load_or_clear_adv_search)
      allow(controller).to receive(:replace_search_box)
      allow(controller).to receive(:update_partials)
      allow(controller).to receive(:render)

      allow(controller).to receive(:items_per_page).and_return(20)
      allow(controller).to receive(:gtl_type).and_return("list")
      allow(controller).to receive(:current_page).and_return(1)
      controller.send(:build_accordions_and_trees)
    end
    it "renders right cell text for root node" do
      key = ems_key_for_provider(@provider)
      controller.send(:get_node_info, "root")
      right_cell_text = controller.instance_variable_get(:@right_cell_text)
      expect(right_cell_text).to eq("All Configuration Management Providers")
    end

    it "renders right cell text for ConfigurationManagerForeman node" do
      ems_id = ems_key_for_provider(@provider)
      controller.instance_variable_set(:@_params, :id => ems_id)
      controller.send(:tree_select)
      right_cell_text = controller.instance_variable_get(:@right_cell_text)
      expect(right_cell_text).to eq("Configuration Profiles under Foreman Provider \"testForeman Configuration Manager\"")
    end
  end

  it "builds foreman child tree" do
    controller.send(:build_configuration_manager_tree, :providers, :configuration_manager_providers_tree)
    tree_builder = TreeBuilderConfigurationManager.new("root", "", {})
    objects = tree_builder.send(:x_get_tree_custom_kids, {:id => "fr"}, false, {})
    expected_objects = [@config_mgr, @config_mgr2]
    expect(objects).to match_array(expected_objects)
  end

  it "builds ansible tower child tree" do
    controller.send(:build_configuration_manager_tree, :providers, :configuration_manager_providers_tree)
    tree_builder = TreeBuilderConfigurationManager.new("root", "", {})
    objects = tree_builder.send(:x_get_tree_custom_kids, {:id => "at"}, false, {})
    expected_objects = [@config_ans, @config_ans2]
    expect(objects).to match_array(expected_objects)
  end

  it "constructs the ansible tower inventory tree node" do
    controller.send(:build_configuration_manager_tree, :providers, :configuration_manager_providers_tree)
    tree_builder = TreeBuilderConfigurationManager.new("root", "", {})
    objects = tree_builder.send(:x_get_tree_objects, @inventory_group, nil, false, nil)
    expected_objects = [@ans_configured_system, @ans_configured_system2a]
    expect(objects).to match_array(expected_objects)
  end

  it "foreman unassigned configuration profile tree node does not list ansible configured systems" do
    controller.send(:build_configuration_manager_tree, :providers, :configuration_manager_providers_tree)
    tree_builder = TreeBuilderConfigurationManager.new("root", "", {})
    objects = tree_builder.send(:x_get_tree_objects, @inventory_group, nil, false, nil)
    expected_objects = [@ans_configured_system, @ans_configured_system2a]
    expect(objects).to match_array(expected_objects)
    unassigned_id = "#{ems_id_for_provider(@provider)}-unassigned"
    unassigned_configuration_profile = ConfigurationProfile.new(:name       => "Unassigned Profiles Group|#{unassigned_id}",
                                                                :manager_id => ems_id_for_provider(@provider))
    objects = tree_builder.send(:x_get_tree_cpf_kids, unassigned_configuration_profile, false)
    expected_objects = [@configured_system_unprovisioned]
    expect(objects).to match_array(expected_objects)
  end

  it "builds ansible tower job templates tree" do
    controller.send(:build_configuration_manager_tree, :configuration_scripts, :configuration_scripts_tree)
    tree_builder = TreeBuilderConfigurationManagerConfigurationScripts.new("root", "", {})
    objects = tree_builder.send(:x_get_tree_roots, false, {})
    expected_objects = [@config_ans, @config_ans2]
    expect(objects).to match_array(expected_objects)
  end

  it "constructs the ansible tower job templates tree node" do
    login_as user_with_feature(%w(providers_accord configured_systems_filter_accord configuration_scripts_accord))
    controller.send(:build_configuration_manager_tree, :configuration_scripts, :configuration_scripts_tree)
    tree_builder = TreeBuilderConfigurationManagerConfigurationScripts.new("root", "", {})
    objects = tree_builder.send(:x_get_tree_roots, false, {})
    objects = tree_builder.send(:x_get_tree_cmat_kids, objects[0], false)
    expected_objects = [@ans_job_template1, @ans_job_template3]
    expect(objects).to match_array(expected_objects)
  end

  context "renders tree_select" do
    before do
      get :explorer
      right_cell_text = nil
      login_as user_with_feature(%w(providers_accord configured_systems_filter_accord configuration_scripts_accord))
      controller.instance_variable_set(:@right_cell_text, right_cell_text)
      allow(controller).to receive(:get_view_calculate_gtl_type)
      allow(controller).to receive(:get_view_pages)
      allow(controller).to receive(:build_listnav_search_list)
      allow(controller).to receive(:load_or_clear_adv_search)
      allow(controller).to receive(:replace_search_box)
      allow(controller).to receive(:update_partials)
      allow(controller).to receive(:render)

      allow(controller).to receive(:items_per_page).and_return(20)
      allow(controller).to receive(:gtl_type).and_return("list")
      allow(controller).to receive(:current_page).and_return(1)
      controller.send(:build_accordions_and_trees)
    end

    it "renders the list view based on the nodetype(root,provider,config_profile) and the search associated with it" do
      controller.instance_variable_set(:@_params, :id => "root")
      controller.instance_variable_set(:@search_text, "manager")
      controller.send(:tree_select)
      view = controller.instance_variable_get(:@view)
      expect(view.table.data.size).to eq(4)

      controller.instance_variable_set(:@_params, :id => "xx-fr")
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

      controller.instance_variable_set(:@_params, :id => "xx-at")
      controller.instance_variable_set(:@search_text, "manager")
      controller.send(:tree_select)
      view = controller.instance_variable_get(:@view)
      expect(view.table.data.size).to eq(2)

      ems_id = ems_key_for_ans_provider(@provider_ans)
      controller.instance_variable_set(:@_params, :id => ems_id)
      controller.send(:tree_select)
      view = controller.instance_variable_get(:@view)
      expect(view.table.data[0].name).to eq("testinvgroup")

      controller.instance_variable_set(:@_params, :id => "xx-at")
      controller.instance_variable_set(:@search_text, "2")
      controller.send(:tree_select)
      view = controller.instance_variable_get(:@view)
      expect(view.table.data[0].name).to eq("ansibletest2 Configuration Manager")

      invgroup_id2 = inventory_group_key(@inventory_group2)
      controller.instance_variable_set(:@_params, :id => invgroup_id2)
      controller.send(:tree_select)
      view = controller.instance_variable_get(:@view)
      expect(view.table.data[0].hostname).to eq("test2b_ans_configured_system")

      controller.instance_variable_set(:@search_text, "2b")
      controller.send(:tree_select)
      view = controller.instance_variable_get(:@view)
      expect(view.table.data[0].hostname).to eq("test2b_ans_configured_system")

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
      expect(view.table.data.size).to eq(4)
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

    it "renders tree_select for ansible tower job templates tree node" do
      allow(controller).to receive(:x_active_tree).and_return(:configuration_scripts_tree)
      controller.instance_variable_set(:@_params, :id => "configuration_scripts")
      controller.send(:accordion_select)
      controller.instance_variable_set(:@_params, :id => "at-" + ApplicationRecord.compress_id(@config_ans.id))
      controller.send(:tree_select)
      view = controller.instance_variable_get(:@view)
      expect(view.table.data[0].name).to eq("ConfigScript1")
      expect(view.table.data[1].name).to eq("ConfigScript3")
    end

    it "calls get_view with the associated dbname for the Configuration Management Providers accordion" do
      stub_user(:features => :all)
      allow(controller).to receive(:x_active_tree).and_return(:configuration_manager_providers_tree)
      allow(controller).to receive(:x_active_accord).and_return(:configuration_manager_providers)
      allow(controller).to receive(:build_listnav_search_list)
      controller.instance_variable_set(:@_params, :id => "configuration_manager_providers_accord")
      expect(controller).to receive(:get_view).with("ManageIQ::Providers::ConfigurationManager", :dbname => :cm_providers).and_call_original
      controller.send(:accordion_select)
    end

    it "calls get_view with the associated dbname for the Configured Systems accordion" do
      stub_user(:features => :all)
      allow(controller).to receive(:x_active_tree).and_return(:cs_filter_tree)
      allow(controller).to receive(:x_active_accord).and_return(:cs_filter)
      allow(controller).to receive(:build_listnav_search_list)
      controller.instance_variable_set(:@_params, :id => "cs_filter_accord")
      expect(controller).to receive(:get_view).with("ConfiguredSystem", :dbname => :cm_configured_systems).and_call_original
      allow(controller).to receive(:build_listnav_search_list)
      controller.send(:accordion_select)
    end

    it "calls get_view with the associated dbname for the Configuration Scripts accordion" do
      stub_user(:features => :all)
      allow(controller).to receive(:x_active_tree).and_return(:configuration_scripts_tree)
      allow(controller).to receive(:x_active_accord).and_return(:configuration_scripts)
      controller.instance_variable_set(:@_params, :id => "configuration_scripts")
      expect(controller).to receive(:get_view).with("ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfigurationScript", :dbname => :configuration_scripts).and_call_original
      controller.send(:accordion_select)
    end
  end

  it "singularizes breadcrumb name" do
    expect(controller.send(:breadcrumb_name, nil)).to eq("#{ui_lookup(:ui_title => "foreman")} Provider")
  end

  it "renders tagging editor for a configured system" do
    session[:tag_items] = [@configured_system.id]
    session[:assigned_filters] = []
    allow(controller).to receive(:x_active_accord).and_return(:cs_filter)
    parent = FactoryGirl.create(:classification, :name => "test_category")
    FactoryGirl.create(:classification_tag,      :name => "test_entry",         :parent => parent)
    FactoryGirl.create(:classification_tag,      :name => "another_test_entry", :parent => parent)
    post :tagging, :params => { :id => @configured_system.id, :format => :js }
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

    stub_user(:features => :all)

    key = ems_key_for_provider(@provider)
    post :tree_select, :params => { :id => key, :format => :js }
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
      post :tree_select, :params => { :id => key }
      expect(response.status).to eq(200)
      expect(response.body).not_to include('<div class=\"hidden btn-group dropdown\"><button data-explorer=\"true\" title=\"Configuration\"')
    end
  end

  context "ansible tower job template accordion " do
    before do
      login_as user_with_feature(%w(providers_accord configured_systems_filter_accord configuration_scripts_accord))
      controller.instance_variable_set(:@right_cell_text, nil)
    end
    render_views

    it 'can render details for a job template' do
      @record = FactoryGirl.create(:ansible_configuration_script,
                                   :name        => "ConfigScript1",
                                   :survey_spec => {'spec' => [{'index' => 0, 'question_description' => 'Survey',
                                                                'min' => nil, 'default' => nil, 'max' => nil,
                                                                'question_name' => 'Survey', 'required' => false,
                                                                'variable' => 'test', 'choices' => nil,
                                                                'type' => 'text'}]})
      tree_node_id = "cf-" + ApplicationRecord.compress_id(@record.id)
      allow(controller).to receive(:x_active_tree).and_return(:configuration_scripts_tree)
      allow(controller).to receive(:x_active_accord).and_return(:configuration_scripts)
      allow(controller).to receive(:x_node).and_return(tree_node_id)
      get :explorer
      expect(response.status).to eq(200)
      expect(response.body).to include("Question Name")
      expect(response.body).to include("Question Description")
    end
  end

  context "fetches the list setting:Grid/Tile/List from settings" do
    before do
      login_as user_with_feature(%w(providers_accord configured_systems_filter_accord))
      allow(controller).to receive(:items_per_page).and_return(20)
      allow(controller).to receive(:current_page).and_return(1)
      allow(controller).to receive(:get_view_pages)
      allow(controller).to receive(:build_listnav_search_list)
      allow(controller).to receive(:load_or_clear_adv_search)
      allow(controller).to receive(:replace_search_box)
      allow(controller).to receive(:update_partials)
      allow(controller).to receive(:render)

      controller.instance_variable_set(:@settings,
                                       :views    => {:cm_providers          => "grid",
                                                     :cm_configured_systems => "tile"})
      controller.send(:build_accordions_and_trees)
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
      user_filters = {'belongs' => [], 'managed' => [tags]}
      allow_any_instance_of(User).to receive(:get_filters).and_return(user_filters)
      controller.send(:build_configuration_manager_tree, :providers, :configuration_manager_providers_tree)
      first_child = find_treenode_for_foreman_provider(@provider)
      expect(first_child).to eq(nil)
    end

    it "builds foreman tree with only those nodes that contain the filtered configured systems" do
      user_filters = {'belongs' => [], 'managed' => [tags]}
      allow_any_instance_of(User).to receive(:get_filters).and_return(user_filters)
      Classification.seed
      quota_2gb_tag = Classification.where("description" => "2GB").first
      Classification.bulk_reassignment(:model      => "ConfiguredSystem",
                                       :object_ids => @configured_system.id,
                                       :add_ids    => quota_2gb_tag.id,
                                       :delete_ids => [])
      controller.send(:build_configuration_manager_tree, :providers, :configuration_manager_providers_tree)
      node1 = find_treenode_for_foreman_provider(@provider)
      node2 = find_treenode_for_foreman_provider(@provider2)
      expect(node1).not_to be_nil
      expect(node2).to be_nil
    end
  end

  context "#configscript_service_dialog" do
    before(:each) do
      stub_user(:features => :all)
      @cs = FactoryGirl.create(:ansible_configuration_script)
      @dialog_label = "New Dialog 01"
      session[:edit] = {
        :new    => {:dialog_name => @dialog_label},
        :key    => "cs_edit__#{@cs.id}",
        :rec_id => @cs.id
      }
      controller.instance_variable_set(:@sb, :trees => {:configuration_scripts_tree => {:open_nodes => []}}, :active_tree => :configuration_scripts_tree)
      controller.instance_variable_set(:@_response, ActionDispatch::TestResponse.new)
    end

    after(:each) do
      expect(controller.send(:flash_errors?)).not_to be_truthy
      expect(response.status).to eq(200)
    end

    it "displays the new dialog form with no reset button" do
      post :x_button, :params => {:pressed => 'configscript_service_dialog', :id => @cs.id}
      expect(response.status).to eq(200)
      expect(response.body).to include('Save Changes')
      expect(response.body).not_to include('Reset')
    end

    it "Service Dialog is created from an Ansible Tower Job Template" do
      controller.instance_variable_set(:@_params, :button => "save", :id => @cs.id)
      allow(controller).to receive(:replace_right_cell)
      controller.send(:configscript_service_dialog_submit)
      expect(assigns(:flash_array).first[:message]).to include("was successfully created")
      expect(Dialog.where(:label => @dialog_label).first).not_to be_nil
      expect(assigns(:edit)).to be_nil
    end

    it "renders tagging editor for a job template system" do
      session[:tag_items] = [@cs.id]
      session[:assigned_filters] = []
      allow(controller).to receive(:x_active_accord).and_return(:configuration_scripts)
      allow(controller).to receive(:tagging_explorer_controller?).and_return(true)
      parent = FactoryGirl.create(:classification, :name => "test_category")
      FactoryGirl.create(:classification_tag,      :name => "test_entry",         :parent => parent)
      FactoryGirl.create(:classification_tag,      :name => "another_test_entry", :parent => parent)
      post :tagging, :params => {:id => @cs.id, :format => :js}
      expect(response.status).to eq(200)
      expect(response.body).to include('Job Template (Ansible Tower) Being Tagged')
    end
  end

  context "when a configured system belonging to an unassigned configuration profile is selected in the list" do
    it "calls tree_select to select the unassigned configuration profile node in the tree" do
      allow(controller).to receive(:check_privileges)
      allow(controller).to receive(:build_listnav_search_list)
      allow(controller).to receive(:x_node).and_return("-1000000000013-unassigned")
      post :x_show, :params => {:id => "1r1", :format => :js}
      expect(response.status).to eq(200)
    end
  end

  def user_with_feature(features)
    features = EvmSpecHelper.specific_product_features(*features)
    FactoryGirl.create(:user, :features => features)
  end

  def find_treenode_for_foreman_provider(provider)
    key = ems_key_for_provider(provider)
    tree = JSON.parse(controller.instance_variable_get(:@configuration_manager_providers_tree))
    tree[0]['nodes'][0]['nodes'].find { |c| c['key'] == key } unless tree[0]['nodes'][0]['nodes'].nil?
  end

  def ems_key_for_provider(provider)
    ems = ExtManagementSystem.where(:provider_id => provider.id).first
    "fr-" + ApplicationRecord.compress_id(ems.id)
  end

  def ems_key_for_ans_provider(provider)
    ems = ExtManagementSystem.where(:provider_id => provider.id).first
    "at-" + ApplicationRecord.compress_id(ems.id)
  end

  def config_profile_key(config_profile)
    cp = ConfigurationProfile.where(:id => config_profile.id).first
    "cp-" + ApplicationRecord.compress_id(cp.id)
  end

  def inventory_group_key(inv_group)
    ig =  ManageIQ::Providers::ConfigurationManager::InventoryGroup.where(:id => inv_group.id).first
    "f-" + ApplicationRecord.compress_id(ig.id)
  end

  def ems_id_for_provider(provider)
    ems = ExtManagementSystem.where(:provider_id => provider.id).first
    ems.id
  end
end
