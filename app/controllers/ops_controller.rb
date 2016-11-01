class OpsController < ApplicationController
  # Methods for accordions
  include_concern 'Db'
  include_concern 'Diagnostics'
  include_concern 'OpsRbac'
  include_concern 'Settings'

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def index
    redirect_to :action => 'explorer'
  end

  OPS_X_BUTTON_ALLOWED_ACTIONS = {
    'collect_logs'              => :logs_collect,
    'collect_current_logs'      => :collect_current_logs,
    'db_refresh'                => :db_refresh,
    'delete_server'             => :delete_server,
    'demote_server'             => :demote_server,
    'fetch_audit_log'           => :fetch_audit_log,
    'fetch_log'                 => :fetch_log,
    'fetch_production_log'      => :fetch_production_log,
    'log_depot_edit'            => :log_depot_edit,
    'promote_server'            => :promote_server,
    'rbac_group_add'            => :rbac_group_add,
    'rbac_group_edit'           => :rbac_group_edit,
    'rbac_group_delete'         => :rbac_group_delete,
    'rbac_group_seq_edit'       => :rbac_group_seq_edit,
    'rbac_group_tags_edit'      => :rbac_tags_edit,
    'rbac_role_add'             => :rbac_role_add,
    'rbac_role_edit'            => :rbac_role_edit,
    'rbac_role_copy'            => :rbac_role_copy,
    'rbac_role_delete'          => :rbac_role_delete,
    'rbac_user_add'             => :rbac_user_add,
    'rbac_user_edit'            => :rbac_user_edit,
    'rbac_user_copy'            => :rbac_user_copy,
    'rbac_user_delete'          => :rbac_user_delete,
    'rbac_user_tags_edit'       => :rbac_tags_edit,
    'rbac_tenant_add'           => :rbac_tenant_add,
    'rbac_project_add'          => :rbac_tenant_add,
    'rbac_tenant_delete'        => :rbac_tenant_delete,
    'rbac_tenant_edit'          => :rbac_tenant_edit,
    'rbac_tenant_manage_quotas' => :rbac_tenant_manage_quotas,
    'rbac_tenant_tags_edit'     => :rbac_tenant_tags_edit,
    'refresh_audit_log'         => :refresh_audit_log,
    'refresh_log'               => :refresh_log,
    'refresh_production_log'    => :refresh_production_log,
    'refresh_server_summary'    => :refresh_server_summary,
    'refresh_workers'           => :refresh_workers,
    'reload_server_tree'        => :reload_server_tree,
    'restart_server'            => :restart_server,
    'restart_workers'           => :restart_workers,
    'role_start'                => :role_start,
    'role_suspend'              => :role_suspend,
    'ap_edit'                   => :ap_edit,
    'ap_delete'                 => :ap_delete,
    'ap_host_edit'              => :ap_host_edit,
    'ap_vm_edit'                => :ap_vm_edit,
    'ap_copy'                   => :ap_copy,
    'zone_collect_logs'         => :logs_collect,
    'zone_collect_current_logs' => :collect_current_logs,
    'zone_delete_server'        => :delete_server,
    'zone_demote_server'        => :demote_server,
    'zone_log_depot_edit'       => :log_depot_edit,
    'zone_promote_server'       => :promote_server,
    'zone_role_start'           => :role_start,
    'zone_role_suspend'         => :role_suspend,
    'zone_delete'               => :zone_delete,
    'zone_edit'                 => :zone_edit,
    'zone_new'                  => :zone_edit,
    'delete_build'              => :delete_build,
    'schedule_add'              => :schedule_add,
    'schedule_edit'             => :schedule_edit,
    'schedule_delete'           => :schedule_delete,
    'schedule_enable'           => :schedule_enable,
    'schedule_disable'          => :schedule_disable,
    'ldap_region_add'           => :ldap_region_add,
    'ldap_region_edit'          => :ldap_region_edit,
    'ldap_domain_add'           => :ldap_domain_add,
    'ldap_domain_edit'          => :ldap_domain_edit,
  }.freeze

  def collect_current_logs
    assert_privileges("#{x_node.split('-').first == "z" ? "zone_" : ""}collect_current_logs")
    logs_collect(:only_current => true)
  end

  # handle buttons pressed on the center buttons toolbar
  def x_button
    @sb[:action] = action = params[:pressed]

    unless OPS_X_BUTTON_ALLOWED_ACTIONS.key?(action)
      raise ActionController::RoutingError, _('invalid button action')
    end

    send(OPS_X_BUTTON_ALLOWED_ACTIONS[action])
  end

  def explorer
    @explorer = true
    @trees = []
    return if perfmenu_click?

    # if AJAX request, replace right cell, and return
    if request.xml_http_request?
      get_node_info(x_node)
      return
    end

    @sb[:active_tab] = 'settings_rhn' if @sb[:active_tab] == 'settings_rhn_edit' # cannot return to the edit state
    @timeline = @timeline_filter = true # Load timeline JS modules
    return unless load_edit(params[:edit_key], "explorer") if params[:edit_key]
    @breadcrumbs = []
    build_accordions_and_trees

    @sb[:rails_log] = $rails_log.filename.to_s.include?("production.log") ? "Production" : "Development"

    if !params[:no_refresh]
      @sb[:good] = nil
      @sb[:buildinfo] = nil
      @sb[:activating] = false
      @build = nil
      @sb[:user] = nil
      @ldap_group = nil
    elsif %w(settings_import settings_import_tags).include?(@sb[:active_tab])
      session[:changed] = !flash_errors?
    end
    # setting active record object here again, since they are no longer there due to redirect
    @ldap_group = @edit[:ldap_group] if params[:cls_id] && params[:cls_id].split('_')[0] == "lg"
    @x_edit_buttons_locals = set_form_locals if @in_a_form
    @collapse_c_cell = @in_a_form || @pages ? false : true
    @sb[:center_tb_filename] = center_toolbar_filename
    edit_changed? if @edit && !%w(settings_import settings_import_tags).include?(@sb[:active_tab])
    render :layout => "application"
  end

  def accordion_select
    session[:flash_msgs] = @flash_array = nil           # clear out any messages from previous screen i.e import tab
    self.x_active_accord = params[:id].sub(/_accord$/, '')
    self.x_active_tree   = "#{self.x_active_accord}_tree"
    session[:changed] = false
    set_active_tab(x_node)
    get_node_info(x_node)
    replace_right_cell(@nodetype)
  end

  def tree_select
    session[:flash_msgs] = @flash_array = nil           # clear out any messages from previous screen i.e import tab
    @sb[:active_node] ||= {}
    self.x_node = params[:id]
    set_active_tab(params[:id])
    session[:changed] = false
    self.x_node = params[:id] # if x_active_tree == :vmdb_tree #params[:action] == "x_show"
    get_node_info(params[:id])
    replace_right_cell(@nodetype)
  end

  def change_tab(new_tab_id = nil)
    @explorer = true
    session[:changed] = false
    session[:flash_msgs] = @flash_array = nil       # clear out any messages from previous screen i.e import tab
    if params[:tab]
      @edit = session[:edit]
      @scan = @edit[:scan]
      case params[:tab].split("_")[0]
      when "new"
        redirect_to(:action => "ap_new", :tab => params[:tab], :id => (@scan.id.to_s || "new"))
      when "edit"
        redirect_to(:action => "ap_edit", :tab => params[:tab], :id => (@scan.id.to_s || "new"))
      else
        @sb[:miq_tab] = "new#{params[:tab]}"
        redirect_to(:action => "ap_edit", :tab => "edit#{params[:tab]}", :id => (@scan.id.to_s || "new"))
      end
    else
      @sb[:active_tab] = params[:tab_id] || new_tab_id
      @sb[:user] = nil
      @ldap_group = nil
      @flash_array = nil if MiqServer.my_server(true).logon_status == :ready  # don't reset if flash array
      if x_active_tree == :settings_tree
        settings_get_info
        replace_right_cell("root")
      elsif x_active_tree == :vmdb_tree
        db_get_info
        replace_right_cell("root")
      elsif x_active_tree == :diagnostics_tree
        case @sb[:active_tab]
        when "diagnostics_roles_servers"
          @sb[:diag_tree_type] = "roles"
          @sb[:diag_selected_id] = nil
        when "diagnostics_servers_roles"
          @sb[:diag_tree_type] = "servers"
          @sb[:diag_selected_id] = nil
        end
        diagnostics_set_form_vars
        replace_right_cell("root")
      end
    end
  end

  private ############################

  def features
    [{:role     => "ops_settings",
      :name     => :settings,
      :title    => _("Settings")},

     {:role     => "ops_rbac",
      :role_any => true,
      :name     => :rbac,
      :title    => _("Access Control")},

     {:role     => "ops_diagnostics",
      :name     => :diagnostics,
      :title    => _("Diagnostics")},

     {:role     => "ops_db",
      :name     => :vmdb,
      :title    => _("Database")},
    ].map do |hsh|
      ApplicationController::Feature.new_with_hash(hsh)
    end
  end

  def set_active_elements(feature)
    if feature
      self.x_active_tree ||= feature.tree_list_name
      self.x_active_accord ||= feature.accord_name
    end
    set_active_tab_and_node
    get_node_info(x_node)
  end

  def set_active_tab_and_node
    if x_active_tree == :settings_tree
      @sb[:active_tab] ||= "settings_server"
    end

    if x_active_tree == :rbac_tree
      x_node_set("root", :rbac_tree) unless x_node(:rbac_tree)
      @sb[:active_tab] ||= "rbac_details"
    end

    if x_active_tree == :diagnostics_tree
      x_node_set("svr-#{to_cid(my_server_id)}", :diagnostics_tree) unless x_node(:diagnostics_tree)
      @sb[:active_tab] ||= "diagnostics_summary"
    end

    if x_active_tree == :vmdb_tree
      x_node_set("root", :vmdb_tree) unless x_node(:vmdb_tree)
      @sb[:active_tab] ||= "db_summary"
    end

    @sb[:tab_label] ||= ui_lookup(:models => "Zone")
    @sb[:active_node] ||= {}

    if MiqServer.my_server(true).logon_status != :ready
      @sb[:active_tab]   = "diagnostics_audit_log"
      self.x_active_tree = 'diagnostics_tree'
    else
      @sb[:active_tab] ||= "settings_server"
    end
  end

  def edit_changed?
    current = @edit[:current].kind_of?(Hash) ? @edit[:current] : @edit[:current].try(:config)
    session[:changed] = @edit[:new] != current
  end

  def rbac_and_user_make_subarrays
    unless @set_filter_values.blank?
      temp_categories = []
      temp1arr = []
      @set_filter_values = @set_filter_values.flatten
      temp_categories = @set_filter_values.dup
      temp_categories = temp_categories.sort
      i = 0
      temp_field = []
      while i < temp_categories.length
        a = temp_categories[i].rindex("/")
        current = temp_categories[i].slice(0..a)
        previous = current if previous.nil?

        if current == previous
          temp_field.push(temp_categories[i])
        else
          temp1arr.push(temp_field)
          temp_field = []
          temp_field.push(temp_categories[i])
          previous = current
        end
        i += 1
      end
      unless temp_field.nil?
        temp1arr.push(temp_field)
      end
      @set_filter_values.replace(temp1arr)
    end
  end

  def set_active_tab(nodetype)
    node = nodetype.downcase.split("-")
    case x_active_tree
    when :settings_tree
      case node[0]
      when "root"
        @sb[:active_tab] = "settings_details"
      when "z"
        @sb[:active_tab] = "settings_evm_servers"
      when "xx", "sis", "msc", "l", "lr", "ld"
        @sb[:active_tab] = "settings_list"
      when "svr"
        @sb[:active_tab] = "settings_server"
      end
    when :rbac_tree
      @sb[:active_tab] = "rbac_details"
    when :diagnostics_tree
      case node[0]
      when "root"
        @sb[:active_tab] = "diagnostics_zones"
      when "z"
        @sb[:active_tab] = "diagnostics_roles_servers"
        @sb[:diag_tree_type] = "roles"
        @sb[:diag_selected_id] = nil
      when "svr"
        @sb[:active_tab] = "diagnostics_summary"
        svr = MiqServer.find(from_cid(node[1]))
      end
    when :vmdb_tree
      nodes = x_node.split('-')
      @sb[:active_tab] = %w(ti xx).include?(nodes[0]) ? "db_indexes" : "db_summary"
    end
  end

  def set_form_locals
    locals = {}
    if x_active_tree == :diagnostics_tree
      if @sb[:active_tab] == "diagnostics_cu_repair"
        action_url = "cu_repair"
        locals[:submit_button] = true
        locals[:submit_text] = _("Select Start date and End date to Collect C & U Data")
        locals[:no_reset] = true
        locals[:no_cancel] = true
      elsif @sb[:active_tab] == "diagnostics_collect_logs"
        action_url = "log_depot_edit"
        record_id = @record && @record.id ? @record.id : "new"
      else
        action_url = "old_dialogs_update"
        record_id = my_server_id
      end
    elsif x_active_tree == :settings_tree
      if %w(settings_import settings_import_tags).include?(@sb[:active_tab])
        action_url = "apply_imports"
        record_id = @sb[:active_tab].split("settings_").last
        locals[:no_reset] = true
        locals[:apply_button] = true
        locals[:no_cancel] = true
        locals[:apply_method] = :post
        if @sb[:active_tab] == "settings_import"
          locals[:apply_text] = _("Apply the good VM custom variable value records")
        elsif @sb[:active_tab] == "settings_import_tags"
          locals[:apply_text] = _("Apply the good import records")
        end
      elsif @sb[:active_tab] == "settings_cu_collection"
        action_url = "cu_collection_update"
        record_id = @sb[:active_tab].split("settings_").last
        locals[:no_cancel] = true
      elsif %w(settings_evm_servers settings_list).include?(@sb[:active_tab]) && @in_a_form
        if %w(ap_copy ap_edit ap_host_edit ap_vm_edit).include?(@sb[:action])
          action_url = "ap_edit"
          record_id = @edit[:scan_id] ? @edit[:scan_id] : nil
        elsif %w(ldap_region_add ldap_region_edit).include?(@sb[:action])
          action_url = "ldap_region_edit"
          record_id = @edit[:ldap_region_id] ? @edit[:ldap_region_id] : nil
        elsif %w(ldap_domain_add ldap_domain_edit).include?(@sb[:action])
          action_url = "ldap_domain_edit"
          record_id = @edit[:ldap_domain_id] ? @edit[:ldap_domain_id] : nil
        elsif %w(schedule_add schedule_edit).include?(@sb[:action])
          action_url = "schedule_edit"
          record_id = @edit[:sched_id] ? @edit[:sched_id] : nil
        elsif %w(zone_edit zone_new).include?(@sb[:action])
          locals[:serialize] = true
          action_url = "zone_edit"
          record_id = @edit[:zone_id] ? @edit[:zone_id] : nil
        end
      elsif @sb[:active_tab] == "settings_co_categories" && @in_a_form
        action_url = "category_edit"
        record_id = @category.try(:id)
      elsif @sb[:active_tab] == "settings_label_tag_mapping" && @in_a_form
        action_url = "label_tag_mapping_edit"
        record_id = @lt_map.try(:id)
      elsif @sb[:active_tab] == 'settings_rhn_edit'
        locals[:no_cancel] = false
        action_url = "settings_update"
        record_id  = @sb[:active_tab].split("settings_").last
      else
        action_url = "settings_update"
        record_id = @sb[:active_tab].split("settings_").last
        locals[:no_cancel] = true
        locals[:serialize] = true if @sb[:active_tab] == "settings_advanced"
      end
    elsif x_active_tree == :rbac_tree
      if %w(rbac_user_add rbac_user_copy rbac_user_edit).include?(@sb[:action])
        action_url = "rbac_user_edit"
        record_id = @edit[:user_id] ? @edit[:user_id] : nil
      elsif %w(rbac_role_add rbac_role_copy rbac_role_edit).include?(@sb[:action])
        action_url = "rbac_role_edit"
        record_id = @edit[:role_id] ? @edit[:role_id] : nil
      elsif %w(rbac_group_add rbac_group_edit).include?(@sb[:action])
        action_url = "rbac_group_edit"
        record_id = @edit[:group_id] ? @edit[:group_id] : nil
      elsif %(rbac_group_tags_edit rbac_user_tags_edit rbac_tenant_tags_edit).include?(@sb[:action])
        action_url = "rbac_tags_edit"
        locals[:multi_record] = true    # need save/cancel buttons on edit screen even tho @record.id is not there
        record_id = @edit[:object_ids][0]
      elsif @sb[:action] == "rbac_group_seq_edit"
        action_url = "rbac_group_seq_edit"
        locals[:multi_record] = true
      end
    end
    locals[:action_url] = action_url
    locals[:record_id] = record_id
    locals
  end

  # Get all info for the node about to be displayed
  def get_node_info(treenodeid)
    return if params[:cls_id] # no need to do get_node_info if redirected from show_product_update
    @nodetype = valid_active_node(treenodeid).split("-").first
    if @replace_trees
      @sb[:active_tab] = case x_active_tree
                         when :diagnostics_tree then 'diagnostics_zones'
                         when :settings_tree    then 'settings_details'
                         end
    end

    @explorer = true
    @nodetype = x_node.split("-").first
    case x_active_tree
    when :diagnostics_tree then diagnostics_get_info
    when :rbac_tree        then rbac_get_info
    when :settings_tree    then settings_get_info
    when :vmdb_tree        then db_get_info
    end

    region_text = _("[Region: %{description} [%{region}]]") % {:description => MiqRegion.my_region.description,
                                                               :region      => MiqRegion.my_region.region}
    @right_cell_text ||= case x_active_tree
                         when :diagnostics_tree then _("Diagnostics %{text}") % {:text => region_text}
                         when :settings_tree    then _("Settings %{text}") % {:text => region_text}
                         when :rbac_tree        then _("Access Control %{text}") % {:text => region_text}
                         when :vmdb_tree        then _("Database []")
                         end
  end

  def open_parent_nodes
    existing_node = nil                     # Init var

    parent_rec = VmdbTableEvm.find_by_id(@record.vmdb_table_id)
    parents = [parent_rec, {:id => @record.vmdb_table_id.to_s}]
    # Go up thru the parents and find the highest level unopened, mark all as opened along the way
    # Skip if no parents or parent already open
    unless parents.empty? || x_tree[:open_nodes].include?(x_build_node_id(parents.last))
      parents.reverse_each do |p|
        p_node = x_build_node_id(p)
        unless x_tree[:open_nodes].include?(p_node)
          x_tree[:open_nodes].push(p_node)
          existing_node = p_node
        end
      end
      tree_add_child_nodes(existing_node) # Build the new nodes hash
    end
  end

  def replace_right_cell(nodetype, replace_trees = []) # replace_trees can be an array of tree symbols to be replaced
    # get_node_info might set this
    replace_trees = @replace_trees if @replace_trees
    @explorer = true

    # Clicked on right cell record, open the tree enough to show the node,
    # if not already showing a record
    # Not in a form
    add_nodes = open_parent_nodes if params[:action] == "x_show" && @record && !@in_a_form
    locals = set_form_locals if @in_a_form
    build_supported_depots_for_select

    presenter = ExplorerPresenter.new(
      :active_tree => x_active_tree,
    )
    # Update the tree with any new nodes
    presenter[:add_nodes] = add_nodes if add_nodes

    r = proc { |opts| render_to_string(opts) }

    replace_explorer_trees(replace_trees, presenter)
    rebuild_toolbars(presenter)
    handle_bottom_cell(nodetype, presenter, r, locals)
    x_active_tree_replace_cell(nodetype, presenter, r)
    extra_js_commands(presenter)

    render :json => presenter.for_render
  end

  def x_active_tree_replace_cell(nodetype, presenter, r)
    case x_active_tree
    when :rbac_tree
      rbac_replace_right_cell(nodetype, presenter, r)
    when :settings_tree
      settings_replace_right_cell(nodetype, presenter, r)
    when :diagnostics_tree
      diagnostics_replace_right_cell(nodetype, presenter, r)
    when :vmdb_tree # "root","tb", "ti","xx" # Check if vmdb root or table is selected
      # Need to replace all_tabs to show table name as tab label
      presenter.replace(:ops_tabs, r[:partial => "all_tabs"])
    end
  end

  def diagnostics_replace_right_cell(nodetype, presenter, r)
    # need to refresh all_tabs for server by roles and roles by servers screen
    # to show correct buttons on screen when tree node is selected
    if %w(accordion_select change_tab explorer tree_select).include?(params[:action]) ||
       %w(diagnostics_roles_servers diagnostics_servers_roles).include?(@sb[:active_tab])
      presenter.replace(:ops_tabs, r[:partial => "all_tabs"])
    elsif nodetype == "log_depot_edit"
      @right_cell_text = _("Editing Log Depot settings")
      presenter.update(:diagnostics_collect_logs, r[:partial => "ops/log_collection"])
    else
      presenter.update(@sb[:active_tab], r[:partial => "#{@sb[:active_tab]}_tab"])
    end
    # zone level
    presenter[:build_calendar] = {} if x_node.split("-").first == "z"
  end

  def settings_replace_right_cell(nodetype, presenter, r)
    case nodetype
    when "ze"     # zone edit
      # when editing zone in settings tree
      if @zone.id.blank?
        partial_div = :settings_list
        @right_cell_text = _("Adding a new %{model}") % {:model => ui_lookup(:model => "Zone")}
      else
        partial_div = :settings_evm_servers
        @right_cell_text = @edit ?
          _("Editing %{model} \"%{name}\"") % {:name => @zone.description, :model => ui_lookup(:model => "Zone")} :
          _("%{model} \"%{name}\"") % {:model => ui_lookup(:model => "Zone"), :name => @zone.description}
      end
      presenter[:update_partials][partial_div] = r[:partial => "zone_form"]
    when "ce"     # category edit
      # when editing/adding category in settings tree
      presenter.update(:settings_co_categories, r[:partial => "category_form"])
      if !@category
        @right_cell_text = _("Adding a new Category")
      else
        @right_cell_text = _("Editing %{model} \"%{name}\"") % {:name => @category.description, :model => "Category"}
      end
    when "ltme" # label tag mapping edit
      # when editing/adding label tag mapping in settings tree
      presenter.update(:settings_label_tag_mapping, r[:partial => "label_tag_mapping_form"])
      if !@lt_map
        @right_cell_text = _("Adding a new Mapping")
      else
        @right_cell_text = _("Editing tag mapping from label \"%{name}\"") % {:name  => @lt_map.label_name}
      end
    when "sie"        # scanitemset edit
      #  editing/adding scanitem in settings tree
      presenter.update(:settings_list, r[:partial => "ap_form"])
      if !@scan.id
        @right_cell_text = _("Adding a new %{model}") % {:model => ui_lookup(:model => "ScanItemSet")}
      else
        @right_cell_text = @edit ?
          _("Editing %{model} \"%{name}\"") % {:name => @scan.name, :model => ui_lookup(:model => "ScanItemSet")} :
          _("%{model} \"%{name}\"") % {:model => ui_lookup(:model => "ScanItemSet"), :name => @scan.name}
      end
    when "se"         # schedule edit
      # when editing/adding schedule in settings tree
      presenter.update(:settings_list, r[:partial => "schedule_form"])
      presenter[:build_calendar] = {
        :date_from => (Time.zone.now - 1.month).in_time_zone(@edit[:tz]),
      }
      if !@schedule.id
        @right_cell_text = _("Adding a new %{model}") % {:model => ui_lookup(:model => "MiqSchedule")}
      else
        model = ui_lookup(:model => "MiqSchedule")
        @right_cell_text = @edit ?
          _("Editing %{model} \"%{name}\"") % {:name => @schedule.name, :model => model} :
          _("%{model} \"%{name}\"") % {:model => model, :name => @schedule.name}
      end
    when "lde"          # ldap_region edit
      # when editing/adding ldap domain in settings tree
      presenter.update(:settings_list, r[:partial => "ldap_domain_form"])
      if !@ldap_domain.id
        @right_cell_text = _("Adding a new %{model}") % {:model => ui_lookup(:model => "LdapDomain")}
      else
        model = ui_lookup(:model => "LdapDomain")
        @right_cell_text = @edit ?
          _("Editing %{model} \"%{name}\"") % {:name => @ldap_domain.name, :model => model} :
          _("%{model} \"%{name}\"") % {:model => model, :name => @ldap_domain.name}
      end
    when "lre"          # ldap_region edit
      # when edi ting/adding ldap region in settings tree
      presenter.update(:settings_list, r[:partial => "ldap_region_form"])
      if !@ldap_region.id
        @right_cell_text = _("Adding a new %{model}") % {:model => ui_lookup(:model => "LdapRegion")}
      else
        model = ui_lookup(:model => "LdapRegion")
        @right_cell_text = @edit ?
          _("Editing %{model} \"%{name}\"") % {:name => @ldap_region.name, :model => model} :
          _("%{model} \"%{name}\"") % {:model => model, :name => @ldap_region.name}
      end
    when 'rhn'          # rhn subscription edit
      presenter[:update_partials][:settings_rhn] = r[:partial => "#{@sb[:active_tab]}_tab"]
    else
      if %w(accordion_select change_tab tree_select).include?(params[:action]) &&
         params[:tab_id] != "settings_advanced"
        presenter.replace(:ops_tabs, r[:partial => "all_tabs"])
      elsif %w(zone_delete).include?(params[:pressed])
        presenter.replace(:ops_tabs, r[:partial => "all_tabs"])
      else
        presenter[:update_partials][@sb[:active_tab.to_sym]] = r[:partial => "#{@sb[:active_tab]}_tab"]
      end
      active_id = from_cid(x_node.split("-").last)
      # server node
      if x_node.split("-").first == "svr" && my_server_id == active_id.to_i
        # show all the tabs if on current server node
        @selected_server ||= MiqServer.find(@sb[:selected_server_id])  # Reread the server record
        presenter.one_trans_ie if %w(save reset).include?(params[:button]) && is_browser_ie?
      elsif x_node.split("-").first == "svr" && my_server_id != active_id.to_i
        # show only 4 tabs if not on current server node
        @selected_server ||= MiqServer.find(@sb[:selected_server_id])  # Reread the server record
      end
    end
  end

  def rbac_replace_right_cell(nodetype, presenter, r)
    @sb[:tab_label] = @tagging ? _("Tagging") : rbac_set_tab_label
    if %w(accordion_select change_tab tree_select).include?(params[:action])
      presenter.replace(:ops_tabs, r[:partial => "all_tabs"])
    elsif nodetype == "group_seq"
      presenter.replace(:flash_msg_div, r[:partial => "layouts/flash_msg"])
      presenter.update(:rbac_details, r[:partial => "ldap_seq_form"])
    elsif nodetype == "tenant_edit"         # schedule edit
      # when editing/adding schedule in settings tree
      presenter.update(:rbac_details, r[:partial => "tenant_form"])
      if !@tenant.id
        @right_cell_text = _("Adding a new %{tenant}") %
          {:tenant => tenant_type_title_string(params[:tenant_type] == "tenant")}
      else
        model = tenant_type_title_string(@tenant.divisible)
        @right_cell_text = @edit ?
          _("Editing %{model} \"%{name}\"") % {:name => @tenant.name, :model => model} :
          _("%{model} \"%{name}\"") % {:model => model, :name => @tenant.name}
      end
    elsif nodetype == "tenant_manage_quotas"         # manage quotas
      # when managing quotas for a tenant
      presenter.update(:rbac_details, r[:partial => "tenant_quota_form"])
      model = tenant_type_title_string(@tenant.divisible)
      @right_cell_text = @edit ?
          _("Manage quotas for %{model} \"%{name}\"") % {:name => @tenant.name, :model => model} :
          _("%{model} \"%{name}\"") % {:model => model, :name => @tenant.name}
    else
      presenter[:update_partials][@sb[:active_tab].to_sym] = r[:partial => "#{@sb[:active_tab]}_tab"]
    end
  end

  def rbac_set_tab_label
    nodes = x_node.split("-")
    case nodes.first
    when "xx"
      case nodes.last
      when "u"
        _("Users")
      when "g"
        _("Groups")
      when "ur"
        _("Roles")
      when "tn"
        _("Tenants")
      end
    when "u"
      @user.name || _("Users")
    when "g"
      if @record && @record.id
        @record.description
      elsif @group && @group.id
        @group.description
      else
        _("Groups")
      end
    when "ur"
      @role.name || _("Roles")
    when "tn"
      @tenant.name || _("Tenants")
    else
      _("Details")
    end
  end

  def extra_js_commands(presenter)
    presenter[:right_cell_text] = @right_cell_text
    presenter[:osf_node] = x_node
    presenter.reset_one_trans
    presenter.focus('server_company')
    presenter[:ajax_action] = {
      :controller => controller_name,
      :action     => @ajax_action,
      :record_id  => @record.id
    } if @ajax_action
  end

  def rebuild_toolbars(presenter)
    unless @in_a_form
      @sb[:center_tb_filename] = center_toolbar_filename
      c_tb = build_toolbar(@sb[:center_tb_filename])
    end
    # Rebuild the toolbars
    presenter.reload_toolbars(:center => c_tb)
    presenter.set_visibility(c_tb.present? && @sb[:center_tb_filename] != "blank_view_tb", :toolbar)
    presenter[:record_id] = determine_record_id_for_presenter
  end

  def handle_bottom_cell(nodetype, presenter, r, locals)
    # Handle bottom cell
    if @pages || @in_a_form
      if @pages
        presenter.hide(:form_buttons_div).show(:pc_div_1)
        presenter.update(:paging_div, r[:partial => "layouts/x_pagingcontrols"])
      elsif @in_a_form
        if nodetype == "log_depot_edit"
          presenter.update(:form_buttons_div, r[:partial => "layouts/angular/paging_div_buttons"])
        else
          presenter.update(:form_buttons_div, r[:partial => "layouts/x_edit_buttons", :locals => locals])
        end
        presenter.show(:form_buttons_div).hide(:pc_div_1)
      end
      presenter.show(:paging_div)
    else
      presenter.hide(:paging_div)
    end
  end

  def replace_explorer_trees(replace_trees, presenter)
    # Build hash of trees to replace and optional new node to be selected
    trees = {}
    if replace_trees
      trees[:settings]    = settings_build_tree     if replace_trees.include?(:settings)
      trees[:rbac]        = rbac_build_tree         if replace_trees.include?(:rbac)
      trees[:diagnostics] = diagnostics_build_tree  if replace_trees.include?(:diagnostics)
      trees[:vmdb]        = db_build_tree           if replace_trees.include?(:vmdb)
    end
    replace_trees_by_presenter(presenter, trees)
  end

  # Build the audit object when a profile is saved
  def build_saved_audit(record, add = false)
    name = record.respond_to?(:name) ? record.name : record.description
    msg = if add
            _("[%{name}] Record added (") % {:name => name}
          else
            _("[%{name}] Record updated (") % {:name => name}
          end
    event = "#{record.class.to_s.downcase}_record_#{add ? "add" : "update"}"
    i = 0
    @edit[:new].each_key do |k|
      if @edit[:new][k] != @edit[:current][k]
        if k.to_s.ends_with?("password2", "verify")      # do nothing
        elsif k.to_s.ends_with?("password", "_pwd")  # Asterisk out password fields
          msg = _("%{message} %{key}:[*] to [*]") % {:message => msg, :key => k.to_s}
        else
          msg += ", " if i > 0
          i += 1
          if k == :members
            msg = _("%{message} %{key}:[%{old_value}] to [new_value]") %
                  {:message   => msg,
                   :key       => k.to_s,
                   :old_value => @edit[:current][k].keys.join(","),
                   :new_value => @edit[:new][k].keys.join(",")}
          else
            msg = _("%{message} %{key}:[%{old_value}] to [new_value]") % {:message   => msg,
                                                                          :key       => k.to_s,
                                                                          :old_value => @edit[:current][k].to_s,
                                                                          :new_value => @edit[:new][k].to_s}
          end
        end
      end
    end
    msg += ")"
    audit = {:event => event, :target_id => record.id, :target_class => record.class.base_class.name, :userid => session[:userid], :message => msg}
  end

  def identify_tl_or_perf_record
    identify_record(@sb[:record_id], @sb[:record_class].constantize)
  end

  def get_session_data
    @title         = _("Configuration")
    @layout        = "ops"
    @tasks_options = session[:tasks_options] || ""
  end

  def set_session_data
    session[:tasks_options] = @tasks_options unless @tasks_options.nil?
  end
end
