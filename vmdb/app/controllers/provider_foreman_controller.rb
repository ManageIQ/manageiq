class ProviderForemanController < ApplicationController
  before_filter :check_privileges
  before_filter :get_session_data

  after_filter :cleanup_action
  after_filter :set_session_data

  def index
    redirect_to :action => 'explorer'
  end

  def show_list
    redirect_to :action => 'explorer'
  end

  def new
    assert_privileges("provider_foreman_add_provider")
    @provider_foreman = ProviderForeman.new
    render_form
  end

  def edit
    case params[:button]
    when "cancel"
      cancel_provider_foreman
    when "save"
      add_provider_foreman
      save_provider_foreman
    else
      assert_privileges("provider_foreman_edit_provider")
      @provider_foreman = find_by_id_filtered(ConfigurationManagerForeman,
                                              from_cid(params[:miq_grid_checks] || params[:id]))
      render_form
    end
  end

  def delete
    assert_privileges("provider_foreman_delete_provider")
    checked_items = find_checked_items
    checked_items.push(params[:id]) if params[:id]
    foremen = ConfigurationManagerForeman.where(:id => checked_items).pluck(:provider_id)
    if foremen.empty?
      add_flash(_("No %{model} were selected for %{task}") % {:model => ui_lookup(:tables => "providers"),
                                                              :task  => "deletion"}, :error)
    else
      ProviderForeman.find_all_by_id(foremen, :order => "lower(name)").each do |foreman|
        id = foreman.id
        provider_name = foreman.name
        audit = {:event        => "foreman_record_delete_initiated",
                 :message      => "[#{provider_name}] Record delete initiated",
                 :target_id    => id,
                 :target_class => "ProviderForeman",
                 :userid       => session[:userid]}
        AuditEvent.success(audit)
      end
      ProviderForeman.destroy_queue(foremen)
      add_flash(_("%{task} initiated for %{count_model} from the CFME Database") %
                    {:task        => "Delete",
                     :count_model => pluralize(foremen.length, "Provider")})
    end
    replace_right_cell
  end

  def refresh
    assert_privileges("provider_foreman_refresh_provider")
    @explorer = true
    foreman_button_operation('refresh_ems', 'Refresh')
    replace_right_cell
  end

  def provision
    assert_privileges("provider_foreman_configured_system_provision") if x_active_accord == :foreman_providers
    assert_privileges("configured_system_provision") if x_active_accord == :cs_filter
    provisioning_ids = find_checked_items
    provisioning_ids.push(params[:id]) if provisioning_ids.empty?

    if ConfiguredSystem.common_configuration_profiles_for_selected_configured_systems(provisioning_ids)
      render :update do |page|
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
    assert_privileges("provider_foreman_configured_system_tag") if x_active_accord == :foreman_providers
    assert_privileges("configured_system_tag") if x_active_accord == :cs_filter
    tagging_edit('ConfiguredSystem', false)
    render_tagging_form
  end

  def add_provider_foreman
    if params[:id] == "new"
      @provider_foreman = ProviderForeman.new(:name       => params[:name],
                                              :url        => params[:url],
                                              :zone_id    => Zone.find_by_name(MiqServer.my_zone).id,
                                              :verify_ssl => params[:verify_ssl].eql?("on"))
    else
      config_mgr = ConfigurationManagerForeman.find(params[:id])
      @provider_foreman = ProviderForeman.find(config_mgr.provider_id)
      @provider_foreman.update_attributes(:name       => params[:name],
                                          :url        => params[:url],
                                          :verify_ssl => params[:verify_ssl].eql?("on"))

    end
    update_authentication_provider_foreman
  end

  def update_authentication_provider_foreman
    creds = {}
    creds[:default] = {:userid   => params[:log_userid],
                       :password => params[:log_password]
    }
    save = params[:id] == "new" ? false : true
    @provider_foreman.update_authentication(creds, :save => save)
  end

  def save_provider_foreman
    if @provider_foreman.save
      construct_edit
      AuditEvent.success(build_created_audit(@provider_foreman, @edit))
      @in_a_form = false
      @sb[:action] = nil
      model = "#{ui_lookup(:ui_title => 'foreman')} #{ui_lookup(:model => 'ExtManagementSystem')}"
      add_flash(_("%{model} \"%{name}\" was %{action}") % {:model  => model,
                                                           :name   => @provider_foreman.name,
                                                           :action => params[:id] == "new" ? "added" : "updated"})
      process_foreman([@provider_foreman.configuration_manager.id], "refresh_ems") if params[:id] == "new"
      replace_right_cell([:foreman_providers])
    else
      @provider_foreman.errors.each do |field, msg|
        @in_a_form = false
        @sb[:action] = nil
        add_flash("#{field.to_s.capitalize} #{msg}", :error)
        replace_right_cell
      end
    end
  end

  def cancel_provider_foreman
    @in_a_form = false
    @sb[:action] = nil
    model = "#{ui_lookup(:ui_title => 'foreman')} #{ui_lookup(:model => 'ExtManagementSystem')}"
    add_flash(_("%{action} %{model} was cancelled by the user") %
                  {:model  => model,
                   :action => params[:id] == "new" ? "Add of" : "Edit of"})
    replace_right_cell
  end

  def provider_foreman_form_fields
    assert_privileges("provider_foreman_edit_provider")
    config_mgr_foreman = find_by_id_filtered(ConfigurationManagerForeman, params[:id])
    provider_foreman = ProviderForeman.find(config_mgr_foreman.provider_id)
    authentications_foreman = Authentication.where(:resource_id => provider_foreman[:id], :resource_type => "Provider")

    render :json => {
      :name         => provider_foreman.name,
      :url          => provider_foreman.url,
      :verify_ssl   => provider_foreman.verify_ssl,
      :log_userid   => authentications_foreman[0].userid,
      :log_password => authentications_foreman[0].password,
      :log_verify   => authentications_foreman[0].password
    }
  end

  def authentication_validate
    @provider_foreman = ProviderForeman.new(:name       => params[:name],
                                            :url        => params[:url],
                                            :zone_id    => Zone.find_by_name(MiqServer.my_zone).id,
                                            :verify_ssl => params[:verify_ssl].eql?("on"))
    update_authentication_provider_foreman

    begin
      @provider_foreman.verify_credentials(params[:type])
    rescue StandardError => bang
      add_flash("#{bang}", :error)
    else
      add_flash(_("Credential validation was successful"))
    end
    render :update do |page|
      page.replace("flash_msg_div", :partial => "layouts/flash_msg")
    end
  end

  def show(id = nil)
    @flash_array = [] if params[:display]
    @sb[:action] = nil

    @display = params[:display] || "main"
    @lastaction = "show"
    @showtype = "config"
    @record =
      identify_record(id || params[:id], configuration_profile_record? ? ConfigurationProfile : ConfiguredSystem)
    return if record_no_longer_exists?(@record)

    @explorer = true if request.xml_http_request? # Ajax request means in explorer

    @gtl_url = "/provider_foreman/show/#{@record.id}?"
    set_summary_pdf_data if "download_pdf" == @display
  end

  def tree_select
    @lastaction = "explorer"
    @flash_array = nil
    self.x_active_tree = params[:tree] if params[:tree]
    self.x_node = params[:id]
    load_or_clear_adv_search

    unless action_name == "reload"
      if %w(x_show x_search_by_name).include?(action_name) && configuration_profile_record?
        @sb[:active_tab] = 'configured_systems'
      else
        @sb[:active_tab] = 'summary'
      end
      replace_right_cell
    else
      replace_right_cell([:foreman_providers])
    end
  end

  def accordion_select
    @lastaction = "explorer"

    @sb[:foreman_search_text] ||= {}
    @sb[:foreman_search_text]["#{x_active_accord}_search_text"] = @search_text

    self.x_active_accord = params[:id]
    self.x_active_tree   = "#{params[:id]}_tree"

    @search_text = @sb[:foreman_search_text]["#{x_active_accord}_search_text"]

    load_or_clear_adv_search
    replace_right_cell
  end

  def load_or_clear_adv_search
    adv_search_build("ConfiguredSystem")
    session[:edit] = @edit

    if x_tree[:type] != :filter || x_node == "root"
      listnav_search_selected(0)
    else
      @nodetype, id = valid_active_node(x_node).split("_").last.split("-")

      if x_tree[:type] == :filter && @nodetype == "ms"
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
    if x_active_tree == :foreman_providers_tree
      @record = foreman_providers_tree_rec
    elsif x_active_tree == :cs_filter_tree
      @record = cs_filter_tree_rec
    end
    respond_to do |format|
      format.js do
        unless @record
          redirect_to :action => "explorer"
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
      format.any { render :nothing => true, :status => 404 }  # Anything else, just send 404
    end
  end

  def foreman_providers_tree_rec
    nodes = x_node.split('-')
    case nodes.first
    when "root" then  rec = identify_record(params[:id], ConfigurationManagerForeman)
    when "e"    then  rec = identify_record(params[:id], ConfigurationProfileForeman)
    when "cp"   then  rec = identify_record(params[:id], ConfiguredSystemForeman)
    end
    rec
  end

  def cs_filter_tree_rec
    nodes = x_node.split('-')
    case nodes.first
    when "root" then  rec = identify_record(params[:id], ConfiguredSystem)
    when "ms"   then  rec = identify_record(from_cid(params[:id]), ConfiguredSystem)
    end
    rec
  end

  def show_record(_id = nil)
    @display = params[:display] || "main" unless control_selected?
    @lastaction = "show"
    @showtype   = "config"

    if @record.nil?
      add_flash(_("Error: Record no longer exists in the database"), :error)
      if request.xml_http_request?  && params[:id]  # Is this an Ajax request clicking on a node that no longer exists?
        @delete_node = params[:id]                  # Set node to be removed from the tree
      end
      return
    end

    if @record.class.base_model.to_s == "ConfiguredSystem"
      rec_cls = @record.class.base_model.to_s.underscore
    end
    return unless %w(download_pdf main).include?(@display)
    @showtype = "main"
    @button_group = "#{rec_cls}" if x_active_accord == :cs_filter
    @button_group = "provider_foreman_#{rec_cls}" if x_active_accord == :foreman_providers
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

    # Build the Explorer screen from scratch
    build_trees_and_accordions

    params.merge!(session[:exp_parms]) if session[:exp_parms]  # Grab any explorer parm overrides
    session.delete(:exp_parms)

    if params[:id]
      # if you click on a link to VM on a dashboard widget that will redirect you
      # to explorer with params[:id] and you get into the true branch
      redirected = set_elements_and_redirect_unauthorized_user
    else
      set_active_elements
    end

    render :layout => "explorer" unless redirected
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

  def build_trees_and_accordions
    @trees   = []
    @accords = []

    x_last_active_tree = x_active_tree if x_active_tree
    x_last_active_accord = x_active_accord if x_active_accord

    if role_allows(:feature => "providers_accord", :any => true)
      self.x_active_tree   = 'foreman_providers_tree'
      self.x_active_accord = 'foreman_providers'
      default_active_tree   ||= x_active_tree
      default_active_accord ||= x_active_accord
      build_foreman_tree(:providers, :foreman_providers_tree)
      @trees.push("foreman_providers_tree")
      @accords.push(:name => "foreman_providers", :title => "Providers", :container => "foreman_providers_tree_div")
    end
    if role_allows(:feature => "configured_systems_filter_accord", :any => true)
      self.x_active_tree   = 'cs_filter_tree'
      self.x_active_accord = 'cs_filter'
      default_active_tree   ||= x_active_tree
      default_active_accord ||= x_active_accord
      build_foreman_tree(:filter, :cs_filter_tree)
      @trees.push("cs_filter_tree")
      @accords.push(:name => "cs_filter", :title => "Configured Systems", :container => "cs_filter_tree_div")
    end
    self.x_active_tree = default_active_tree
    self.x_active_accord = default_active_accord.to_s

    self.x_active_tree = x_last_active_tree if x_last_active_tree
    self.x_active_accord = x_last_active_accord.to_s if x_last_active_accord
  end

  def build_foreman_tree(type, name)
    @sb[:open_tree_nodes] ||= []

    if name == :foreman_providers_tree
      tree = TreeBuilderForeman.new(name, type, @sb)
    else
      tree = TreeBuilderForemanConfiguredSystems.new(name, type, @sb)
    end
    @temp[name] = tree.tree_nodes
    tree
  end

  def set_active_elements
    # Set active tree and accord to first allowed feature
    if role_allows(:feature => "providers_accord")
      self.x_active_tree   ||= 'foreman_providers_tree'
      self.x_active_accord ||= 'foreman_providers'
    elsif role_allows(:feature => "configured_systems_filter_accord")
      self.x_active_tree   ||= 'cs_filter_tree'
      self.x_active_accord ||= 'cs_filter'
    end
    get_node_info(x_node)
    @in_a_form = false
  end

  def get_node_info(treenodeid)
    @sb[:action] = nil
    @nodetype, id = valid_active_node(treenodeid).split("_").last.split("-")
    model = TreeBuilder.get_model_for_prefix(@nodetype)
    case model
    when "ExtManagementSystem"
      provider_node(id, model)
    when "ConfigurationProfile"
      configuration_profile_node(id, model)
    when "ConfiguredSystem"
      configured_system_node(id, model)
    when "MiqSearch"
      miq_search_node
    else
      default_node
    end
    @right_cell_text += @edit[:adv_search_applied][:text] if x_tree[:type] == :filter && @edit && @edit[:adv_search_applied]

    if @edit && @edit.fetch_path(:adv_search_applied, :qs_exp) # If qs is active, save it in history
      x_history_add_item(:id     => x_node,
                         :qs_exp => @edit[:adv_search_applied][:qs_exp],
                         :text   => @right_cell_text)
    else
      x_history_add_item(:id => treenodeid, :text => @right_cell_text)  # Add to history pulldown array
    end
  end

  def provider_node(id, model)
    @record = provider = identify_record(id, ExtManagementSystem)
    if provider.nil?
      self.x_node = "root"
      get_node_info("root")
      return
    else
      options = {:model => "ConfigurationProfile"}
      options[:where_clause] = ["configuration_manager_id IN (?)", provider.id]
      @no_checkboxes = true
      process_show_list(options)
      record_model = ui_lookup(:model => model ? model : TreeBuilder.get_model_for_prefix(@nodetype))
      @right_cell_text =
          _("%{model} \"%{name}\"") %
          {:name  => provider.name,
           :model => "#{ui_lookup(:tables => "configuration_profile")} under #{record_model}"}
    end
  end

  def configuration_profile_node(id, model)
    @record = @configuration_profile_record = identify_record(id, ConfigurationProfile)
    if @configuration_profile_record.nil?
      self.x_node = "root"
      get_node_info("root")
      return
    else
      options = {:model => "ConfiguredSystem"}
      options[:where_clause] = ["configuration_profile_id IN (?)", @configuration_profile_record.id]
      process_show_list(options)
      record_model = ui_lookup(:model => model ? model : TreeBuilder.get_model_for_prefix(@nodetype))
      if @sb[:active_tab] == 'configured_systems'
        @right_cell_text =
          _("%{model} \"%{name}\"") %
          {:name  => @configuration_profile_record.name,
           :model => "#{ui_lookup(:tables => "configured_system")} under #{record_model}"}
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

  def configured_system_node(id, model)
    @record = @configured_system_record = identify_record(id, ConfiguredSystem)
    if @record.nil?
      self.x_node = "root"
      get_node_info("root")
      return
    else
      show_record(from_cid(id))
      @right_cell_text =
          _("%{model} \"%{name}\"") %
          {:name  => @record.name,
           :model => "#{ui_lookup(:model => model ? model : TreeBuilder.get_model_for_prefix(@nodetype))}"}
    end
  end

  def miq_search_node
    options = {:model => "ConfiguredSystem"}
    process_show_list(options)
    @right_cell_text = _("All %s Configured Systems") % ui_lookup(:ui_title => "foreman")
  end

  def default_node
    return unless x_node == "root"
    if self.x_active_tree == :foreman_providers_tree
      options = {:model => "ConfigurationManagerForeman"}
      process_show_list(options)
      @right_cell_text = _("All %s Providers") % ui_lookup(:ui_title => "foreman")
    elsif self.x_active_tree == :cs_filter_tree
      options = {:model => "ConfiguredSystem"}
      process_show_list(options)
      @right_cell_text = _("All %s Configured Systems") % ui_lookup(:ui_title => "foreman")
    end
  end

  def rendering_objects
    presenter = ExplorerPresenter.new(
        :active_tree => x_active_tree,
        :temp        => @temp,
        :delete_node => @delete_node,
    )
    r = proc { |opts| render_to_string(opts) }
    return presenter, r
  end

  def render_form
    presenter, r = rendering_objects
    @in_a_form = true
    presenter[:update_partials][:main_div] = r[:partial => 'form', :locals => {:controller => 'provider_foreman'}]
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

    presenter[:update_partials][:main_div] = r[:partial => 'layouts/x_gtl']
    rebuild_toolbars(false, presenter)
    handle_bottom_cell(presenter, r)
    render :js => presenter.to_html
  end

  def update_title(presenter)
    if params[:action] == "new"
      @right_cell_text = _("Add a new %s Provider") % ui_lookup(:ui_title => "foreman")
    elsif params[:pressed] == "provider_foreman_edit_provider"
      @right_cell_text = _("Edit %s Provider") % ui_lookup(:ui_title => "foreman")
    end
    presenter[:right_cell_text] = @right_cell_text
  end

  def replace_right_cell(replace_trees = [])
    return if @in_a_form
    @explorer = true
    @in_a_form = false
    @sb[:action] = nil

    record_showing = leaf_record

    # Build presenter to render the JS command for the tree update
    presenter = ExplorerPresenter.new(
        :active_tree => x_active_tree,
        :temp        => @temp,
        :delete_node => @delete_node,      # Remove a new node from the tree
    )
    r = proc { |opts| render_to_string(opts) }

    update_partials(record_showing, presenter, r)
    replace_search_box(presenter, r)
    handle_bottom_cell(presenter, r)
    replace_explorer_trees(replace_trees, presenter, r)
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

  def configuration_profile_record?
    type, _id = x_node.split("_").last.split("-")
    type && ["ConfigurationProfile"].include?(TreeBuilder.get_model_for_prefix(type))
  end

  def update_partials(record_showing, presenter, r)
    if record_showing
      get_tagdata(@record)
      presenter[:set_visible_elements][:form_buttons_div] = false
      path_dir = "provider_foreman"
      presenter[:update_partials][:main_div] =
          r[:partial => "#{path_dir}/main", :locals => {:controller => 'provider_foreman'}]
    elsif @in_a_form
      partial_locals = {:controller => 'provider_foreman'}
      if @sb[:action] == "provider_foreman_add_provider"
        @right_cell_text = _("Add a new %s Provider") % ui_lookup(:ui_title => "foreman")
      elsif @sb[:action] == "provider_foreman_edit_provider"
        @right_cell_text = _("Edit %s Provider") % ui_lookup(:ui_title => "foreman")
      end
      partial = 'form'
      presenter[:update_partials][:main_div] = r[:partial => partial, :locals => partial_locals]
    elsif @configuration_profile_record
      presenter[:set_visible_elements][:form_buttons_div] = false
      presenter[:update_partials][:main_div] = r[:partial => "configuration_profile",
                                                 :locals  => {:controller => 'provider_foreman'}]
    else
      presenter[:update_partials][:main_div] = r[:partial => 'layouts/x_gtl']
    end
  end

  def replace_search_box(presenter, r)
    # Replace the searchbox
    presenter[:replace_partials][:adv_searchbox_div] =
        r[:partial => 'layouts/x_adv_searchbox',
          :locals  => {:nameonly => ([:foreman_providers_tree].include?(x_active_tree))}]

    # Clear the JS gtl_list_grid var if changing to a type other than list
    presenter[:clear_gtl_list_grid] = @gtl_type && @gtl_type != 'list'
  end

  def handle_bottom_cell(presenter, r)
    # Handle bottom cell
    if @pages || @in_a_form
      if @pages && !@in_a_form
        @ajax_paging_buttons = true
        if @sb[:action] && @record  # Came in from an action link
          presenter[:update_partials][:paging_div] = r[:partial => 'layouts/x_pagingcontrols',
                                                       :locals  => {:action_url    => @sb[:action],
                                                                    :action_method => @sb[:action],
                                                                    :action_id     => @record.id
                                                       }]
        else
          presenter[:update_partials][:paging_div] = r[:partial => 'layouts/x_pagingcontrols']
        end
        presenter[:set_visible_elements][:form_buttons_div] = false
        presenter[:set_visible_elements][:pc_div_1] = true
      elsif @in_a_form
        presenter[:set_visible_elements][:pc_div_1] = false
        presenter[:set_visible_elements][:form_buttons_div] = true
      end
      presenter[:expand_collapse_cells][:c] = 'expand'
    else
      presenter[:expand_collapse_cells][:c] = 'collapse'
    end
  end

  def replace_explorer_trees(replace_trees, presenter, r)
    build_foreman_tree(:providers, :foreman_providers_tree) if replace_trees
    replace_trees.each do |t|
      presenter[:replace_partials]["#{t}_tree_div".to_sym] = r[:partial => "provider_foreman/#{t}_tree"]
    end
  end

  def rebuild_toolbars(record_showing, presenter)
    if configuration_profile_summary_tab_selected?
      center_tb = "blank_view_tb"
      record_showing = true
    end

    if !@in_a_form && !@sb[:action]
      center_tb ||= center_toolbar_filename
      custom_btn_tb = center_tb
      custom_btn_tb ||= "custom_buttons_tb"
      c_buttons,  c_xml  = build_toolbar_buttons_and_xml(center_tb)

      if record_showing
        cb_buttons, cb_xml = build_toolbar_buttons_and_xml(custom_btn_tb)
        v_buttons,  v_xml  = build_toolbar_buttons_and_xml("x_summary_view_tb")
      else
        v_buttons,  v_xml  = build_toolbar_buttons_and_xml("x_gtl_view_tb")
      end
    end

    h_buttons, h_xml = build_toolbar_buttons_and_xml("x_history_tb") unless @in_a_form

    # Rebuild the toolbars
    presenter[:set_visible_elements][:history_buttons_div] = h_buttons  && h_xml
    presenter[:set_visible_elements][:center_buttons_div]  = c_buttons  && c_xml
    presenter[:set_visible_elements][:view_buttons_div]    = v_buttons  && v_xml
    presenter[:set_visible_elements][:custom_buttons_div]  = cb_buttons && cb_xml

    presenter[:reload_toolbars][:history] = {:buttons => h_buttons,  :xml => h_xml}  if h_buttons  && h_xml
    presenter[:reload_toolbars][:center]  = {:buttons => c_buttons,  :xml => c_xml}  if c_buttons  && c_xml
    presenter[:reload_toolbars][:view]    = {:buttons => v_buttons,  :xml => v_xml}  if v_buttons  && v_xml

    presenter[:expand_collapse_cells][:a] = h_buttons || c_buttons || v_buttons ? 'expand' : 'collapse'

    presenter[:miq_record_id] = @record ? @record.id : nil

    # Hide/show searchbox depending on if a list is showing
    presenter[:set_visible_elements][:adv_searchbox_div] = display_adv_searchbox

    presenter[:set_visible_elements][:blocker_div]    = false unless @edit && @edit[:adv_search_open]
    presenter[:set_visible_elements][:quicksearchbox] = false
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

  def construct_edit
    @edit ||= {}
    @edit[:current] = {:name       => @provider_foreman.name,
                       :url        => @provider_foreman.url,
                       :verify_ssl => @provider_foreman.verify_ssl}
    @edit[:new] = {:name       => params[:name],
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
    presenter[:update_partials][:main_div] = r[:partial => 'layouts/tagging',
                                               :locals  => locals_for_tagging]
    presenter[:update_partials][:form_buttons_div] = r[:partial => 'layouts/x_edit_buttons',
                                                       :locals  => locals_for_tagging]
  end

  def clear_flash_msg
    @flash_array = nil if params[:button] != "reset"
  end

  def breadcrumb_name
    "#{ui_lookup(:ui_title => 'foreman')} #{ui_lookup(:model => 'ExtManagementSystem')}"
  end

  def tagging_explorer_controller?
    @explorer
  end

  def set_root_node
    self.x_node = "root"
    get_node_info(x_node)
  end

  def get_session_data
    @title  = "Providers"
    @layout = controller_name
  end

  def set_session_data
  end
end
