class ProviderForemanController < ApplicationController
  before_action :check_privileges
  before_action :get_session_data

  after_action :cleanup_action
  after_action :set_session_data

  def self.model
    ManageIQ::Providers::ConfigurationManager
  end

  def self.table_name
    @table_name ||= "provider_foreman"
  end

  def self.model_to_name(provmodel)
    if provmodel.include?("ManageIQ::Providers::AnsibleTower")
      return ui_lookup(:ui_title => 'ansible_tower')
    elsif provmodel.include?("ManageIQ::Providers::Foreman")
      return ui_lookup(:ui_title => 'foreman')
    end
  end

  def model_to_name(provmodel)
    ProviderForemanController.model_to_name(provmodel)
  end

  def index
    redirect_to :action => 'explorer'
  end

  def show_list
    redirect_to :action => 'explorer', :flash_msg => @flash_array.try(:fetch_path, 0, :message)
  end

  def new
    assert_privileges("provider_foreman_add_provider")
    @provider_cfgmgmt = ManageIQ::Providers::ConfigurationManager.new
    @provider_types = ["Ansible Tower", "Foreman"]
    render_form
  end

  def edit
    @provider_types = ["Ansible Tower", "Foreman"]
    case params[:button]
    when "cancel"
      cancel_provider_foreman
    when "save"
      add_provider_foreman
      save_provider_foreman
    else
      assert_privileges("provider_foreman_edit_provider")
      @provider_cfgmgmt = find_record(ManageIQ::Providers::ConfigurationManager,
                                      from_cid(params[:miq_grid_checks] || params[:id] || find_checked_items[0]))
      @providerdisplay_type = model_to_name(@provider_cfgmgmt.type)
      render_form
    end
  end

  def delete
    assert_privileges("provider_foreman_delete_provider") # TODO: Privelege name should match generic ways from Infra and Cloud
    checked_items = find_checked_items # TODO: Checked items are managers, not providers.  Make them providers
    providers = ManageIQ::Providers::ConfigurationManager.where(:id => checked_items).includes(:provider).collect(&:provider)
    if providers.empty?
      add_flash(_("No %{model} were selected for %{task}") % {:model => ui_lookup(:tables => "providers"), :task => "deletion"}, :error)
    else
      providers.each do |provider|
        AuditEvent.success(
          :event        => "configuration_manager_record_delete_initiated", # TODO: Should be provider_record_delete_initiated
          :message      => "[#{provider.name}] Record delete initiated",
          :target_id    => provider.id,
          :target_class => provider.type,
          :userid       => session[:userid]
        )
        provider.destroy_queue
      end

      add_flash(_("Delete initiated for %{count_model}") % {:count_model => pluralize(providers.length, "provider")})
    end
    replace_right_cell
  end

  def refresh
    assert_privileges("provider_foreman_refresh_provider")
    @explorer = true
    foreman_button_operation('refresh_ems', _('Refresh'))
    replace_right_cell
  end

  def provision
    assert_privileges("provider_foreman_configured_system_provision") if x_active_accord == :configuration_manager_providers
    assert_privileges("configured_system_provision") if x_active_accord == :cs_filter
    provisioning_ids = find_checked_items
    provisioning_ids.push(params[:id]) if provisioning_ids.empty?

    unless ConfiguredSystem.provisionable?(provisioning_ids)
      add_flash(_("Provisioning is not supported for at least one of the selected systems"), :error)
      replace_right_cell
      return
    end

    if ConfiguredSystem.common_configuration_profiles_for_selected_configured_systems(provisioning_ids)
      render :update do |page|
        page << javascript_prologue
        page.redirect_to :controller     => "miq_request",
                         :action         => "prov_edit",
                         :prov_id        => provisioning_ids,
                         :org_controller => "configured_system",
                         :escape         => false
      end
    else
      add_flash(_("No common configuration profiles available for the selected configured %s") % n_('system', 'systems', provisioning_ids.size), :error)
      replace_right_cell
    end
  end

  def tagging
    assert_privileges("provider_foreman_configured_system_tag") if x_active_accord == :configuration_manager_providers
    assert_privileges("configured_system_tag") if x_active_accord == :cs_filter
    tagging_edit('ConfiguredSystem', false)
    render_tagging_form
  end

  def add_provider_foreman
    @provider_cfgmgmt   = provider_class_from_provtype.new if params[:id] == "new"
    @provider_cfgmgmt ||= find_record(ManageIQ::Providers::ConfigurationManager, params[:id]).provider # TODO: Why is params[:id] an ExtManagementSystem ID instead of Provider ID?

    @provider_cfgmgmt.update_attributes(
      :name       => params[:name],
      :url        => params[:url],
      :verify_ssl => params[:verify_ssl].eql?("on"),
      :zone_id    => Zone.find_by_name(MiqServer.my_zone).id,
    )
    update_authentication_provider(:save)
  end

  def update_authentication_provider(mode = :validate)
    @provider_cfgmgmt.update_authentication(build_credentials, :save => mode == :save)
  end

  def build_credentials
    creds = {}
    if params[:log_userid]
      default_password = params[:log_password] ? params[:log_password] : @provider_cfgmgmt.authentication_password
      creds[:default] = {:userid => params[:log_userid], :password => default_password}
    end
    creds
  end

  def save_provider_foreman
    if @provider_cfgmgmt.save
      construct_edit
      AuditEvent.success(build_created_audit(@provider_cfgmgmt, @edit))
      @in_a_form = false
      @sb[:action] = nil
      model = "#{model_to_name(@provider_cfgmgmt.type)} #{ui_lookup(:model => 'ExtManagementSystem')}"
      if params[:id] == "new"
        add_flash(_("%{model} \"%{name}\" was added") % {:model => model,
                                                         :name  => @provider_cfgmgmt.name})
      else
        add_flash(_("%{model} \"%{name}\" was updated") % {:model => model,
                                                           :name  => @provider_cfgmgmt.name})
      end
      if params[:id] == "new"
        process_cfgmgr([@provider_cfgmgmt.configuration_manager.id], "refresh_ems")
      end
      replace_right_cell([:configuration_manager_providers])
    else
      @provider_cfgmgmt.errors.each do |field, msg|
        @in_a_form = false
        @sb[:action] = nil
        add_flash("#{field.to_s.capitalize} #{msg}", :error)
      end
      replace_right_cell
    end
  end

  def cancel_provider_foreman
    @in_a_form = false
    @sb[:action] = nil
    if params[:id] == "new"
      add_flash(_("Add of Configuration Manager %{provider} was cancelled by the user") %
        {:provider  => ui_lookup(:model => 'ExtManagementSystem')})
    else
      add_flash(_("Edit of Configuration Manager %{provider} was cancelled by the user") %
        {:provider  => ui_lookup(:model => 'ExtManagementSystem')})
    end
    replace_right_cell
  end

  def provider_foreman_form_fields
    assert_privileges("provider_foreman_edit_provider")
    config_mgr = find_record(ManageIQ::Providers::ConfigurationManager, params[:id])
    provider   = config_mgr.provider

    render :json => {:provtype   => model_to_name(config_mgr.type),
                     :name       => provider.name,
                     :url        => provider.url,
                     :verify_ssl => provider.verify_ssl,
                     :log_userid => provider.authentications.first.userid}
  end

  def authentication_validate
    @provider_cfgmgmt = if params[:log_password]
                          provider_class_from_provtype.new(
                            :name       => params[:name],
                            :url        => params[:url],
                            :verify_ssl => params[:verify_ssl].eql?("on"),
                            :zone_id    => Zone.find_by_name(MiqServer.my_zone).id,
                          )
                        else
                          find_record(ManageIQ::Providers::ConfigurationManager, params[:id]).provider
                        end

    update_authentication_provider

    begin
      @provider_cfgmgmt.verify_credentials(params[:type])
    rescue StandardError => bang
      add_flash(bang.to_s, :error)
    else
      add_flash(_("Credential validation was successful"))
    end
    render_flash
  end

  def show(id = nil)
    @flash_array = [] if params[:display]
    @sb[:action] = nil

    @display = params[:display] || "main"
    @lastaction = "show"
    @showtype = "config"
    @record = if configuration_profile_record?
                find_record(ConfigurationProfile, id || params[:id])
              elsif inventory_group_record?
                find_record(InventoryRootGroup, id || params[:id])
              else
                find_record(ConfiguredSystem, id || params[:id])
              end
    return if record_no_longer_exists?(@record)

    @explorer = true if request.xml_http_request? # Ajax request means in explorer

    @gtl_url = "/show"
    set_summary_pdf_data if "download_pdf" == @display
  end

  def tree_select
    @lastaction = "explorer"
    @flash_array = nil
    self.x_active_tree = params[:tree] if params[:tree]
    self.x_node = params[:id]
    load_or_clear_adv_search
    apply_node_search_text if x_active_tree == :configuration_manager_providers_tree

    unless action_name == "reload"
      @sb[:active_tab] = if active_tab_configured_systems?
                           'configured_systems'
                         else
                           'summary'
                         end
      replace_right_cell
    else
      replace_right_cell([:configuration_manager_providers])
    end
  end

  def accordion_select
    @lastaction = "explorer"

    @sb[:foreman_search_text] ||= {}
    @sb[:foreman_search_text]["#{x_active_accord}_search_text"] = @search_text

    self.x_active_accord = params[:id].sub(/_accord$/, '')
    self.x_active_tree   = "#{x_active_accord}_tree"

    @search_text = @sb[:foreman_search_text]["#{x_active_accord}_search_text"]

    load_or_clear_adv_search
    replace_right_cell
  end

  def load_or_clear_adv_search
    adv_search_build("ConfiguredSystem")
    session[:edit] = @edit
    @explorer = true

    if x_tree[:type] != :cs_filter || x_node == "root"
      listnav_search_selected(0)
    else
      @nodetype, id = valid_active_node(x_node).split("_").last.split("-")

      if x_tree[:type] == :cs_filter && (@nodetype == "xx-csf" || @nodetype == "xx-csa")
        search_id = @nodetype == "root" ? 0 : from_cid(id)
        listnav_search_selected(search_id) unless params.key?(:search_text) # Clear or set the adv search filter
        if @edit[:adv_search_applied] &&
           MiqExpression.quick_search?(@edit[:adv_search_applied][:exp]) &&
           %w(reload tree_select).include?(params[:action])
          self.x_node = params[:id]
          quick_search_show
          return
        end
      end
    end
  end

  def x_show
    @explorer = true
    tree_record unless unassigned_configuration_profile?(params[:id])

    respond_to do |format|
      format.js do
        unless @record
          check_for_unassigned_configuration_profile
          return
        end
        params[:id] = x_build_node_id(@record)  # Get the tree node id
        tree_select
      end
      format.html do                # HTML, redirect to explorer
        tree_node_id = TreeBuilder.build_node_id(@record)
        session[:exp_parms] = {:id => tree_node_id}
        redirect_to :action => "explorer"
      end
      format.any { head :not_found }  # Anything else, just send 404
    end
  end

  def tree_record
    if x_active_tree == :configuration_manager_providers_tree
      @record = configuration_manager_providers_tree_rec
    elsif x_active_tree == :cs_filter_tree
      @record = cs_filter_tree_rec
    end
  end

  def check_for_unassigned_configuration_profile
    if action_name == "x_show"
      unassigned_configuration_profile?(params[:id]) ? tree_select : tree_select_unprovisioned_configured_system
    elsif action_name == "tree_select"
      tree_select_unprovisioned_configured_system
    else
      redirect_to :action => "explorer"
    end
  end

  def tree_select_unprovisioned_configured_system
    if unassigned_configuration_profile?(params[:id])
      params[:id] = "cs-#{params[:id]}"
      tree_select
    else
      redirect_to :action => "explorer"
    end
  end

  def configuration_manager_providers_tree_rec
    nodes = x_node.split('-')
    type, _id = x_node.split("_").last.split("-")
    case nodes.first
    when "root" then find_record(ManageIQ::Providers::ConfigurationManager, params[:id])
    when "fr"   then find_record(ManageIQ::Providers::Foreman::ConfigurationManager::ConfigurationProfile, params[:id])
    when "at"   then find_record(ManageIQ::Providers::ConfigurationManager::InventoryGroup, params[:id])
    when "f"    then find_record(ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfiguredSystem, params[:id])
    when "cp"   then find_record(ManageIQ::Providers::Foreman::ConfigurationManager::ConfiguredSystem, params[:id])
    when "xx" then
      case nodes.second
      when "at" then find_record(ManageIQ::Providers::AnsibleTower::ConfigurationManager, params[:id])
      when "fr" then find_record(ManageIQ::Providers::Foreman::ConfigurationManager, params[:id])
      when "csa", "csf" then find_record(ConfiguredSystem, params[:id])
      when "at_at" then
        if type == "f"
          find_record(ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfiguredSystem, params[:id])
        else
          find_record(ManageIQ::Providers::ConfigurationManager::InventoryGroup, params[:id])
        end
      when "fr_fr" then
        if type == "cp"
          find_record(ManageIQ::Providers::Foreman::ConfigurationManager::ConfiguredSystem, params[:id])
        else
          find_record(ManageIQ::Providers::Foreman::ConfigurationManager::ConfigurationProfile, params[:id])
        end
      end
    end
  end

  def cs_filter_tree_rec
    nodes = x_node.split('-')
    case nodes.first
    when "root", "xx" then find_record(ConfiguredSystem, params[:id])
    when "ms"         then find_record(ConfiguredSystem, from_cid(params[:id]))
    end
  end

  def show_record(_id = nil)
    @display = params[:display] || "main" unless control_selected?
    @lastaction = "show"
    @showtype   = "config"

    if @record.nil?
      add_flash(_("Error: Record no longer exists in the database"), :error)
      if request.xml_http_request? && params[:id]  # Is this an Ajax request clicking on a node that no longer exists?
        @delete_node = params[:id]                  # Set node to be removed from the tree
      end
      return
    end

    if @record.class.base_model.to_s == "ConfiguredSystem"
      rec_cls = "#{model_to_name(@record.class.to_s).downcase.tr(' ', '_')}_configured_system"
    end
    return unless %w(download_pdf main).include?(@display)
    @showtype = "main"
    @button_group = rec_cls.to_s if x_active_accord == :cs_filter
    @button_group = "provider_foreman_#{rec_cls}" if x_active_accord == :configuration_manager_providers
  end

  def explorer
    @explorer = true
    @lastaction = "explorer"

    # if AJAX request, replace right cell, and return
    if request.xml_http_request?
      replace_right_cell
      return
    end

    if params[:accordion]
      self.x_active_tree   = "#{params[:accordion]}_tree"
      self.x_active_accord = params[:accordion]
    end
    if params[:button]
      @miq_after_onload = "miqAjax('/#{controller_name}/x_button?pressed=#{params[:button]}');"
    end
    params.instance_variable_get(:@parameters).merge!(session[:exp_parms]) if session[:exp_parms]  # Grab any explorer parm overrides
    session.delete(:exp_parms)
    @in_a_form = false
    if params[:id] # If a tree node id came in, show in one of the trees
      nodetype, id = params[:id].split("-")
      # treebuilder initializes x_node to root first time in locals_for_render,
      # need to set this here to force & activate node when link is clicked outside of explorer.
      @reselect_node = self.x_node = "#{nodetype}-#{to_cid(id)}"
    end

    @sb[:open_tree_nodes] ||= []
    build_accordions_and_trees

    render :layout => "application"
  end

  def tree_autoload_dynatree
    @view ||= session[:view]
    super
  end

  def change_tab
    @sb[:active_tab] = params[:tab_id]
    replace_right_cell
  end

  private ###########

  def provider_class_from_provtype
    params[:provtype] == 'Ansible Tower' ? ManageIQ::Providers::AnsibleTower::Provider : ManageIQ::Providers::Foreman::Provider
  end

  def features
    [{:role     => "providers_accord",
      :role_any => true,
      :name     => :configuration_manager_providers,
      :title    => _("Providers")},
     {:role     => "configured_systems_filter_accord",
      :role_any => true,
      :name     => :cs_filter,
      :title    => _("Configured Systems")}
    ].map do |hsh|
      ApplicationController::Feature.new_with_hash(hsh)
    end
  end

  def build_configuration_manager_tree(type, name)
    @sb[:open_tree_nodes] ||= []

    tree = if name == :configuration_manager_providers_tree
             TreeBuilderConfigurationManager.new(name, type, @sb)
           else
             TreeBuilderConfigurationManagerConfiguredSystems.new(name, type, @sb)
           end
    instance_variable_set :"@#{name}", tree.tree_nodes
    tree
  end

  def get_node_info(treenodeid)
    @sb[:action] = nil
    @nodetype, id = valid_active_node(treenodeid).split("_").last.split("-")

    model = TreeBuilder.get_model_for_prefix(@nodetype)
    if model == "Hash"
      model = TreeBuilder.get_model_for_prefix(id)
      id = nil
    end

    case model
    when "ManageIQ::Providers::Foreman::ConfigurationManager", "ManageIQ::Providers::AnsibleTower::ConfigurationManager"
      provider_list(id, model)
    when "ConfigurationProfile"
      configuration_profile_node(id, model)
    when "EmsFolder"
      inventory_group_node(id, model)
    when "ManageIQ::Providers::Foreman::ConfigurationManager::ConfiguredSystem", "ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfiguredSystem", "ConfiguredSystem"
      configured_system_list(id, model)
    when "MiqSearch"
      miq_search_node
    else
      if unassigned_configuration_profile?(treenodeid)
        configuration_profile_node(id, model)
      else
        default_node
      end
    end
    @right_cell_text += @edit[:adv_search_applied][:text] if x_tree && x_tree[:type] == :cs_filter && @edit && @edit[:adv_search_applied]

    if @edit && @edit.fetch_path(:adv_search_applied, :qs_exp) # If qs is active, save it in history
      x_history_add_item(:id     => x_node,
                         :qs_exp => @edit[:adv_search_applied][:qs_exp],
                         :text   => @right_cell_text)
    else
      x_history_add_item(:id => treenodeid, :text => @right_cell_text)  # Add to history pulldown array
    end
  end

  def provider_node(id, model)
    @record = provider = find_record(ExtManagementSystem, id)
    if provider.nil?
      self.x_node = "root"
      get_node_info("root")
      return
    else
      case @record.type
      when "ManageIQ::Providers::Foreman::ConfigurationManager"
        options = {:model => "ConfigurationProfile", :match_via_descendants => ConfiguredSystem, :where_clause => ["manager_id IN (?)", provider.id]}
        @no_checkboxes = true
        process_show_list(options)
        add_unassigned_configuration_profile_record(provider.id)
        record_model = ui_lookup(:model => model_to_name(model || TreeBuilder.get_model_for_prefix(@nodetype)))
        @right_cell_text = _("%{model} \"%{name}\"") % {:name  => provider.name,
                                                        :model => "#{ui_lookup(:tables => "configuration_profile")} under #{record_model} Provider"}
      when "ManageIQ::Providers::AnsibleTower::ConfigurationManager"
        options = {:model => "ManageIQ::Providers::ConfigurationManager::InventoryGroup", :match_via_descendants => ConfiguredSystem, :where_clause => ["ems_id IN (?)", provider.id]}
        @no_checkboxes = true
        process_show_list(options)
        record_model = ui_lookup(:model => model_to_name(model || TreeBuilder.get_model_for_prefix(@nodetype)))
        @right_cell_text = _("%{model} \"%{name}\"") % {:name  => provider.name,
                                                        :model => "#{ui_lookup(:tables => "inventory_group")} under #{record_model} Provider"}
      end
    end
  end

  def provider_list(id, model)
    return provider_node(id, model) unless id.nil?
    if x_active_tree == :configuration_manager_providers_tree
      options = {:model => model.to_s}
      @right_cell_text = _("All %{title} Providers") % {:title => model_to_name(model)}
      process_show_list(options)
    end
  end

  def configuration_profile_node(id, model)
    @record = @configuration_profile_record = if model
                                                find_record(ConfigurationProfile, id)
                                              else
                                                ConfigurationProfile.new
                                              end
    if @configuration_profile_record.nil?
      self.x_node = "root"
      get_node_info("root")
      return
    else
      options = {:model => "ConfiguredSystem", :match_via_descendants => ConfiguredSystem}
      options[:where_clause] = ["configuration_profile_id IN (?)", @configuration_profile_record.id]
      options[:where_clause] =
        ["manager_id IN (?) AND \
          configuration_profile_id IS NULL", id] if empty_configuration_profile_record?(@configuration_profile_record)
      process_show_list(options)
      record_model = ui_lookup(:model => model || TreeBuilder.get_model_for_prefix(@nodetype))
      if @sb[:active_tab] == 'configured_systems'
        configuration_profile_right_cell_text(model)
      else
        @showtype = 'main'
        @pages = nil
        @right_cell_text =
          _("%{model} \"%{name}\"") %
          {:name  => @configuration_profile_record.name,
           :model => record_model
          }
      end
    end
  end

  def inventory_group_node(id, model)
    @record = @inventory_group_record = find_record(ManageIQ::Providers::ConfigurationManager::InventoryGroup, id) if model

    if @inventory_group_record.nil?
      self.x_node = "root"
      get_node_info("root")
    else
      options = {:model => "ConfiguredSystem", :match_via_descendants => ConfiguredSystem}
      options[:where_clause] = ["inventory_root_group_id IN (?)", from_cid(@inventory_group_record.id)]
      process_show_list(options)
      record_model = ui_lookup(:model => model || TreeBuilder.get_model_for_prefix(@nodetype))
      if @sb[:active_tab] == 'configured_systems'
        inventory_group_right_cell_text(model)
      else
        @showtype = 'main'
        @pages = nil
        @right_cell_text = _("%{model} \"%{name}\"") % {:name => @inventory_group_record.name, :model => record_model}
      end
    end
  end

  def configured_system_list(id, model)
    return configured_system_node(id, model) unless id.nil?
    @listicon = "configured_system"
    if x_active_tree == :cs_filter_tree
      options = {:model => model.to_s}
      @right_cell_text = _("All %{title} Configured Systems") % {:title => model_to_name(model)}
      process_show_list(options)
    end
  end

  def configured_system_node(id, model)
    @record = @configured_system_record = find_record(ConfiguredSystem, id)
    if @record.nil?
      self.x_node = "root"
      get_node_info("root")
      return
    else
      show_record(from_cid(id))
      @right_cell_text =
        _("%{model} \"%{name}\"") %
        {:name  => @record.name,
         :model => ui_lookup(:model => model || TreeBuilder.get_model_for_prefix(@nodetype)).to_s}
    end
  end

  def miq_search_node
    options = {:model => "ConfiguredSystem"}
    process_show_list(options)
    @right_cell_text = _("All %{title} Configured Systems") % {:title => ui_lookup(:ui_title => "foreman")}
  end

  def default_node
    return unless x_node == "root"
    if x_active_tree == :configuration_manager_providers_tree
      options = {:model => "ManageIQ::Providers::ConfigurationManager"}
      process_show_list(options)
      @right_cell_text = _("All Configuration Management Providers")
    elsif x_active_tree == :cs_filter_tree
      options = {:model => "ConfiguredSystem"}
      process_show_list(options)
      @right_cell_text = _("All Configured Systems")
    end
  end

  def rendering_objects
    presenter = ExplorerPresenter.new(
      :active_tree => x_active_tree,
      :delete_node => @delete_node,
    )
    r = proc { |opts| render_to_string(opts) }
    return presenter, r
  end

  def render_form
    presenter, r = rendering_objects
    @in_a_form = true
    presenter.update(:main_div, r[:partial => 'form', :locals => {:controller => 'provider_foreman'}])
    update_title(presenter)
    rebuild_toolbars(false, presenter)
    handle_bottom_cell(presenter, r)
    render :js => presenter.to_html
  end

  def render_tagging_form
    return if %w(cancel save).include?(params[:button])
    @in_a_form = true
    @right_cell_text = _("Edit Tags for Configured Systems")
    clear_flash_msg
    presenter, r = rendering_objects
    update_tagging_partials(presenter, r)
    update_title(presenter)
    rebuild_toolbars(false, presenter)
    handle_bottom_cell(presenter, r)
    render :js => presenter.to_html
  end

  def update_tree_and_render_list(replace_trees)
    @explorer = true
    get_node_info(x_node)
    presenter, r = rendering_objects
    replace_explorer_trees(replace_trees, presenter, r)

    presenter.update(:main_div, r[:partial => 'layouts/x_gtl'])
    rebuild_toolbars(false, presenter)
    handle_bottom_cell(presenter, r)
    render :js => presenter.to_html
  end

  def update_title(presenter)
    if action_name == "new"
      @right_cell_text = _("Add a new Configuration Management Provider")
    elsif action_name == "edit"
      @right_cell_text = _("Edit Configuration Manager Provider")
    end
    presenter[:right_cell_text] = @right_cell_text
  end

  def replace_right_cell(replace_trees = [])
    return if @in_a_form
    @explorer = true
    @in_a_form = false
    @sb[:action] = nil

    record_showing = leaf_record
    trees = {}
    trees[:configuration_manager_providers] = build_configuration_manager_tree(:configuration_manager_providers, :configuration_manager_providers_tree) if replace_trees

    # Build presenter to render the JS command for the tree update
    presenter = ExplorerPresenter.new(
      :active_tree => x_active_tree,
      :delete_node => @delete_node,      # Remove a new node from the tree
    )
    r = proc { |opts| render_to_string(opts) }

    update_partials(record_showing, presenter, r)
    replace_search_box(presenter, r)
    handle_bottom_cell(presenter, r)
    replace_trees_by_presenter(presenter, trees)
    rebuild_toolbars(record_showing, presenter)
    presenter[:right_cell_text] = @right_cell_text
    presenter[:osf_node] = x_node  # Open, select, and focus on this node

    # Render the JS responses to update the explorer screen
    render :js => presenter.to_html
  end

  def leaf_record
    get_node_info(x_node)
    @delete_node = params[:id] if @replace_trees
    type, _id = x_node.split("_").last.split("-")
    type && ["ConfiguredSystem"].include?(TreeBuilder.get_model_for_prefix(type))
  end

  def configuration_profile_record?(node = x_node)
    type, _id = node.split("_").last.split("-")
    type && ["ConfigurationProfile"].include?(TreeBuilder.get_model_for_prefix(type))
  end

  def inventory_group_record?(node = x_node)
    type, _id = node.split("_").last.split("-")
    type && ["EmsFolder"].include?(TreeBuilder.get_model_for_prefix(type))
  end

  def foreman_provider_record?(node = x_node)
    node = node.split("-").last if node.split("-").first == 'xx'
    type, _id = node.split("-")
    type && ["ManageIQ::Providers::Foreman::ConfigurationManager"].include?(TreeBuilder.get_model_for_prefix(type))
  end

  def ansible_tower_cfgmgr_record?(node = x_node)
    return  @record.kind_of?(ManageIQ::Providers::AnsibleTower::ConfigurationManager) if @record

    type, _id = node.split("-")
    type && ["ManageIQ::Providers::AnsibleTower::ConfigurationManager"].include?(TreeBuilder.get_model_for_prefix(type))
  end

  def provider_record?(node = x_node)
    foreman_provider_record?(node) || ansible_tower_cfgmgr_record?(node)
  end

  def search_text_type(node)
    return "provider" if provider_record?(node)
    return "configuration_profile" if configuration_profile_record?(node)
    return "inventory_group" if inventory_group_record?(node)
    node
  end

  def apply_node_search_text
    setup_search_text_for_node
    previous_nodetype = search_text_type(@sb[:foreman_search_text][:previous_node])
    current_nodetype = search_text_type(@sb[:foreman_search_text][:current_node])

    @sb[:foreman_search_text]["#{previous_nodetype}_search_text"] = @search_text
    @search_text = @sb[:foreman_search_text]["#{current_nodetype}_search_text"]
    @sb[:foreman_search_text]["#{x_active_accord}_search_text"] = @search_text
  end

  def setup_search_text_for_node
    @sb[:foreman_search_text] ||= {}
    @sb[:foreman_search_text][:current_node] ||= x_node
    @sb[:foreman_search_text][:previous_node] = @sb[:foreman_search_text][:current_node]
    @sb[:foreman_search_text][:current_node] = x_node
  end

  def update_partials(record_showing, presenter, r)
    if record_showing
      get_tagdata(@record)
      presenter.hide(:form_buttons_div)
      path_dir = "provider_foreman"
      presenter.update(:main_div, r[:partial => "#{path_dir}/main",
                                    :locals  => {:controller => 'provider_foreman'}])
    elsif @in_a_form
      partial_locals = {:controller => 'provider_foreman'}
      if @sb[:action] == "provider_foreman_add_provider"
        @right_cell_text = _("Add a new Configuration Manager Provider")
      elsif @sb[:action] == "provider_foreman_edit_provider"
        # set the title based on the configuration manager provider type
        @right_cell_text = _("Edit Configuration Manager Provider")
      end
      partial = 'form'
      presenter.update(:main_div, r[:partial => partial, :locals => partial_locals])
    elsif valid_configuration_profile_record?(@configuration_profile_record)
      presenter.hide(:form_buttons_div)
      presenter.update(:main_div, r[:partial => "configuration_profile",
                                    :locals  => {:controller => 'provider_foreman'}])
    elsif valid_inventory_group_record?(@inventory_group_record)
      presenter.hide(:form_buttons_div)
      presenter.update(:main_div, r[:partial => "inventory_group",
                                    :locals  => {:controller => 'provider_foreman'}])
    else
      presenter.update(:main_div, r[:partial => 'layouts/x_gtl'])
    end
  end

  def replace_search_box(presenter, r)
    # Replace the searchbox
    presenter.replace(:adv_searchbox_div,
                      r[:partial => 'layouts/x_adv_searchbox',
                        :locals  => {:nameonly => x_active_tree == :configuration_manager_providers_tree}])

    presenter[:clear_gtl_list_grid] = @gtl_type && @gtl_type != 'list'
  end

  def handle_bottom_cell(presenter, r)
    # Handle bottom cell
    if @pages || @in_a_form
      if @pages && !@in_a_form
        @ajax_paging_buttons = true
        if @sb[:action] && @record # Came in from an action link
          presenter.update(:paging_div, r[:partial => 'layouts/x_pagingcontrols',
                                          :locals  => {:action_url    => @sb[:action],
                                                       :action_method => @sb[:action],
                                                       :action_id     => @record.id}])
        else
          presenter.update(:paging_div, r[:partial => 'layouts/x_pagingcontrols'])
        end
        presenter.hide(:form_buttons_div).show(:pc_div_1)
      elsif @in_a_form
        presenter.hide(:pc_div_1).show(:form_buttons_div)
      end
      presenter.show(:paging_div)
    else
      presenter.hide(:paging_div)
    end
  end

  def rebuild_toolbars(record_showing, presenter)
    if configuration_profile_summary_tab_selected? || inventory_group_summary_tab_selected?
      center_tb = "blank_view_tb"
      record_showing = true
    end

    if !@in_a_form && !@sb[:action]
      center_tb ||= center_toolbar_filename
      c_tb = build_toolbar(center_tb)

      v_tb = if record_showing
               build_toolbar("x_summary_view_tb")
             else
               build_toolbar("x_gtl_view_tb")
             end
    end

    h_tb = build_toolbar("x_history_tb") unless @in_a_form

    presenter.reload_toolbars(:history => h_tb, :center => c_tb, :view => v_tb)

    presenter.set_visibility(h_tb.present? || c_tb.present? || v_tb.present?, :toolbar)

    presenter[:record_id] = @record ? @record.id : nil

    # Hide/show searchbox depending on if a list is showing
    presenter.set_visibility(display_adv_searchbox, :adv_searchbox_div)
    presenter[:clear_search_show_or_hide] = clear_search_show_or_hide

    presenter.hide(:blocker_div) unless @edit && @edit[:adv_search_open]
    presenter.hide(:quicksearchbox)
    presenter[:hide_modal] = true

    presenter[:lock_unlock_trees][x_active_tree] = @in_a_form
  end

  def display_adv_searchbox
    !(@configured_system_record ||
      @in_a_form ||
      configuration_profile_summary_tab_selected?)
  end

  def configuration_profile_summary_tab_selected?
    @configuration_profile_record && @sb[:active_tab] == 'summary'
  end

  def inventory_group_summary_tab_selected?
    @inventory_group_record && @sb[:active_tab] == 'summary'
  end

  def construct_edit
    @edit ||= {}
    @edit[:current] = {:name       => @provider_cfgmgmt.name,
                       :provtype   => model_to_name(@provider_cfgmgmt.type),
                       :url        => @provider_cfgmgmt.url,
                       :verify_ssl => @provider_cfgmgmt.verify_ssl}
    @edit[:new] = {:name       => params[:name],
                   :provtype   => params[:provtype],
                   :url        => params[:url],
                   :verify_ssl => params[:verify_ssl]}
  end

  def locals_for_tagging
    {:action_url   => 'tagging',
     :multi_record => true,
     :record_id    => @sb[:rec_id] || @edit[:object_ids] && @edit[:object_ids][0]
    }
  end

  def update_tagging_partials(presenter, r)
    presenter.update(:main_div, r[:partial => 'layouts/tagging',
                                  :locals  => locals_for_tagging])
    presenter.update(:form_buttons_div, r[:partial => 'layouts/x_edit_buttons',
                                          :locals  => locals_for_tagging])
  end

  def clear_flash_msg
    @flash_array = nil if params[:button] != "reset"
  end

  def breadcrumb_name(_model)
    "#{ui_lookup(:ui_title => 'foreman')} #{ui_lookup(:model => 'ExtManagementSystem')}"
  end

  def tagging_explorer_controller?
    @explorer
  end

  def active_tab_configured_systems?
    (%w(x_show x_search_by_name).include?(action_name) && (configuration_profile_record? || inventory_group_record?)) ||
      unassigned_configuration_profile?(x_node)
  end

  def unassigned_configuration_profile?(node)
    _type, _pid, nodeinfo = node.split("_").last.split("-")
    nodeinfo == "unassigned"
  end

  def empty_configuration_profile_record?(configuration_profile_record)
    configuration_profile_record.try(:id).nil?
  end

  def valid_configuration_profile_record?(configuration_profile_record)
    configuration_profile_record.try(:id)
  end

  def list_row_id(row)
    if row['name'] == _("Unassigned Profiles Group") && row['id'].nil?
      "-#{row['manager_id']}-unassigned"
    elsif row[:type]
      TreeBuilder.get_prefix_for_model(row[:type]).to_s % to_cid(row['id'])
    else
      to_cid(row['id'])
    end
  end

  def list_row_image(_image, item = nil)
    # Unassigned Profiles Group
    if item.kind_of?(ConfigurationProfile) && empty_configuration_profile_record?(item)
      'folder'
    else
      super
    end
  end

  def configuration_profile_right_cell_text(model)
    record_model = ui_lookup(:model => model || TreeBuilder.get_model_for_prefix(@nodetype))
    return if @sb[:active_tab] != 'configured_systems'
    if valid_configuration_profile_record?(@configuration_profile_record)
      @right_cell_text = _("%{model} under %{record_model} \"%{name}\"") %
                         {:model        => ui_lookup(:tables => "configured_system"),
                          :record_model => record_model,
                          :name         => @configuration_profile_record.name}
    else
      @right_cell_text = _("%{model} under Unassigned Profiles Group") %
                         {:model => ui_lookup(:tables => "configured_system")}
    end
  end

  def add_unassigned_configuration_profile_record(provider_id)
    unprovisioned_configured_systems =
      ConfiguredSystem.where(:manager_id => provider_id, :configuration_profile_id => nil).count

    return if unprovisioned_configured_systems == 0

    unassigned_configuration_profile_desc = unassigned_configuration_profile_name = _("Unassigned Profiles Group")
    unassigned_configuration_profile = ConfigurationProfile.new
    unassigned_configuration_profile.manager_id = provider_id
    unassigned_configuration_profile.name = unassigned_configuration_profile_name
    unassigned_configuration_profile.description = unassigned_configuration_profile_desc

    unassigned_profile_row =
      {'description'                    => unassigned_configuration_profile_desc,
       'total_configured_systems'       => unprovisioned_configured_systems,
       'configuration_environment_name' => unassigned_configuration_profile.configuration_environment_name,
       'my_zone'                        => unassigned_configuration_profile.my_zone,
       'region_description'             => unassigned_configuration_profile.region_description,
       'name'                           => unassigned_configuration_profile_name,
       'manager_id'                     => provider_id
      }

    add_unassigned_configuration_profile_record_to_view(unassigned_profile_row, unassigned_configuration_profile)
  end

  def add_unassigned_configuration_profile_record_to_view(unassigned_profile_row, unassigned_configuration_profile)
    @view.table.data.push(unassigned_profile_row)
    @targets_hash[unassigned_profile_row['id']] = unassigned_configuration_profile
    @grid_hash = view_to_hash(@view)
  end

  def empty_inventory_group_record?(inventory_group_record)
    inventory_group_record.try(:id).nil?
  end

  def valid_inventory_group_record?(inventory_group_record)
    inventory_group_record.try(:id)
  end

  def inventory_group_right_cell_text(model)
    return if @sb[:active_tab] != 'configured_systems'
    if valid_inventory_group_record?(@inventory_group_record)
      record_model = ui_lookup(:model => model || TreeBuilder.get_model_for_prefix(@nodetype))
      @right_cell_text = _("%{model} under Inventory Group \"%{name}\"") %
                         {:model        => ui_lookup(:tables => "configured_system"),
                          :record_model => record_model,
                          :name         => @inventory_group_record.name}
    end
  end

  def process_show_list(options = {})
    options[:dbname] = :cm_providers if x_active_accord == :configuration_manager_providers
    options[:dbname] = :cm_configured_systems if x_active_accord == :cs_filter
    super
  end

  def find_record(model, id)
    raise _("Invalid input") unless is_integer?(from_cid(id))
    begin
      record = model.where(:id => from_cid(id)).first
    rescue ActiveRecord::RecordNotFound, StandardError => ex
      if @explorer
        self.x_node = "root"
        add_flash(ex.message, :error, true)
        session[:flash_msgs] = @flash_array.dup
      end
    end
    record
  end

  def set_root_node
    self.x_node = "root"
    get_node_info(x_node)
  end

  def get_session_data
    @title  = _("Providers")
    @layout = controller_name
  end

  def set_session_data
  end
end
