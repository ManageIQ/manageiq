class OpsController < ApplicationController

  # Methods for accordions
  include_concern 'Analytics'
  include_concern 'Db'
  include_concern 'Diagnostics'
  include_concern 'OpsRbac'
  include_concern 'Settings'

  before_filter :check_privileges
  before_filter :get_session_data
  after_filter :cleanup_action
  after_filter :set_session_data

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
  }.freeze

  def collect_current_logs
    assert_privileges("#{x_node.split('-').first == "z" ? "zone_" : ""}collect_current_logs")
    logs_collect(:only_current => true)
  end

  # handle buttons pressed on the center buttons toolbar
  def x_button
    @sb[:action] = action = params[:pressed]

    raise ActionController::RoutingError.new('invalid button action') unless
      OPS_X_BUTTON_ALLOWED_ACTIONS.key?(action)

    self.send(OPS_X_BUTTON_ALLOWED_ACTIONS[action])
  end

  def explorer
    @explorer = true
    @built_trees = []
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
    @trees   = []
    @accords = []
    if role_allows(:feature => "ops_settings")
      @accords.push(:name => "settings", :title => "Settings", :container => "settings_tree_div")
      self.x_active_accord ||= 'settings'
      self.x_active_tree  ||= 'settings_tree'
      @sb[:active_tab]    ||= "settings_server"
      @built_trees << settings_build_tree
    end
    if role_allows(:feature => "ops_rbac")
      @accords.push(:name => "rbac", :title => "Access Control", :container => "rbac_tree_div")
      self.x_active_accord ||= 'rbac'
      self.x_active_tree   ||= 'rbac_tree'
      @built_trees << rbac_build_tree
      x_node_set("root", :rbac_tree) unless x_node(:rbac_tree)
      @sb[:active_tab] ||= "rbac_details"
    end
    if role_allows(:feature => "ops_diagnostics")
      @accords.push(:name => "diagnostics", :title => "Diagnostics", :container => "diagnostics_tree_div")
      self.x_active_accord ||= 'diagnostics'
      self.x_active_tree   ||= 'diagnostics_tree'
      @built_trees << diagnostics_build_tree
      x_node_set("svr-#{to_cid(@sb[:my_server_id])}", :diagnostics_tree) unless x_node(:diagnostics_tree)
      @sb[:active_tab] ||= "diagnostics_summary"
    end
    if get_vmdb_config[:product][:analytics]
      @accords.push(:name => "analytics", :title => "Analytics", :container => "analytics_tree_div")
      self.x_active_accord ||= 'analytics'
      @built_trees << analytics_build_tree
      x_node_set("svr-#{to_cid(@sb[:my_server_id])}", :analytics_tree) unless x_node(:analytics_tree)
    end
    if role_allows(:feature => "ops_db")
      @accords.push(:name => "vmdb", :title => "Database", :container => "vmdb_tree_div")
      self.x_active_accord ||= 'vmdb'
      self.x_active_tree   ||= 'vmdb_tree'
      @built_trees << db_build_tree
      x_node_set("root", :vmdb_tree) unless x_node(:vmdb_tree)
      @sb[:active_tab] ||= "db_summary"
    end

    @sb[:tab_label] ||= ui_lookup(:models=>"Zone")
    @sb[:active_node] ||= {}
    if MiqServer.my_server(true).logon_status != :ready
      @sb[:active_tab]   = "diagnostics_audit_log"
      self.x_active_tree = 'diagnostics_tree'
    else
      @sb[:active_tab] ||= "settings_server"
    end

    @sb[:rails_log] = $rails_log.filename.to_s.include?("production.log") ? "Production" : "Development"
    get_node_info(x_node) if !params[:cls_id] #no need to do get_node_info if redirected from show_product_update
    if !params[:no_refresh]
      @sb[:good] = nil
      @sb[:buildinfo] = nil
      @sb[:activating] = false
      @build = nil
      @sb[:user] = nil
      @ldap_group = nil
    else
      session[:changed] = @sb[:show_button] if params[:no_refresh] &&
        %w(settings_import settings_import_tags).include?(@sb[:active_tab]) # show apply button enabled if this is set
    end
    # setting active record object here again, since they are no longer there due to redirect
    @ldap_group = @edit[:ldap_group] if params[:cls_id] && params[:cls_id].split('_')[0] == "lg"
    @temp[:x_edit_buttons_locals] = set_form_locals if @in_a_form
    @collapse_c_cell = @in_a_form || @pages ? false : true
    @sb[:center_tb_filename] = center_toolbar_filename
    edit_changed? if @edit
    render :layout => "explorer"
  end

  def accordion_select
    session[:flash_msgs] = @flash_array = nil           #clear out any messages from previous screen i.e import tab
    self.x_active_accord = params[:id]
    self.x_active_tree   = "#{params[:id]}_tree"
    session[:changed] = false
    set_active_tab(x_node)
    get_node_info(x_node)
    replace_right_cell(@nodetype)
  end

  def tree_select
    session[:flash_msgs] = @flash_array = nil           #clear out any messages from previous screen i.e import tab
    @sb[:active_node] ||= Hash.new
    self.x_node = params[:id]
    set_active_tab(params[:id])
    session[:changed] = false
    self.x_node = params[:id] #if x_active_tree == :vmdb_tree #params[:action] == "x_show"
    get_node_info(params[:id])
    replace_right_cell(@nodetype)
  end

  def change_tab(new_tab_id = nil)
    @exlorer = true
    session[:changed] = false
    session[:flash_msgs] = @flash_array = nil       #clear out any messages from previous screen i.e import tab
    if params[:tab]
      @edit = session[:edit]
      @scan = @edit[:scan]
      case params[:tab].split("_")[0]
      when "new"
        redirect_to(:action=>"ap_new", :tab=>params[:tab], :id=>"#{@scan.id || "new"}")
      when "edit"
        redirect_to(:action=>"ap_edit", :tab=>params[:tab], :id=>"#{@scan.id || "new"}")
      else
        @sb[:miq_tab] = "new#{params[:tab]}"
        redirect_to(:action=>"ap_edit", :tab=>"edit#{params[:tab]}", :id=>"#{@scan.id || "new"}")
      end
    else
      @sb[:active_tab] = params[:tab_id] || new_tab_id
      @sb[:user] = nil
      @ldap_group = nil
      @flash_array = nil if MiqServer.my_server(true).logon_status == :ready  # don't reset if flash array
      if x_active_tree == :settings_tree
        settings_get_info(x_node)
        replace_right_cell("root")
      elsif x_active_tree == :vmdb_tree
        db_get_info(x_node)
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

  def edit_changed?
    current = @edit[:current].kind_of?(Hash) ? @edit[:current] : @edit[:current].try(:config)
    session[:changed] = @edit[:new] != current
  end

  def rbac_and_user_make_subarrays
    if ! @set_filter_values.blank?
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
      if ! temp_field.nil?
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
        when "xx", "sis", "msc", "l", "lr","ld"
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
    when :analytics_tree
      @sb[:active_tab] = "analytics_details"
    when :vmdb_tree
      nodes = x_node.split('-')
      @sb[:active_tab] = %w(ti xx).include?(nodes[0]) ? "db_indexes" : "db_summary"
    end
  end

  def set_form_locals
    locals = Hash.new
    if x_active_tree == :diagnostics_tree
      if @sb[:active_tab] == "diagnostics_cu_repair"
        action_url = "cu_repair"
        locals[:submit_button] = true
        locals[:submit_text] = "Select Start date and End date to Collect C & U Data"
        locals[:no_reset] = true
        locals[:no_cancel] = true
      elsif @sb[:active_tab] == "diagnostics_collect_logs"
        action_url = "log_depot_edit"
        record_id = @record && @record.id ? @record.id : "new"
      else
        action_url = "old_dialogs_update"
        record_id = @sb[:my_server_id]
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
          locals[:apply_text] = "Apply the good VM custom variable value records"
        elsif @sb[:active_tab] == "settings_import_tags"
          locals[:apply_text] = "Apply the good import records"
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
        record_id = @category && @category.id ? @category.id : nil
      elsif @sb[:active_tab] == 'settings_rhn_edit'
        locals[:no_cancel] = false
        action_url = "settings_update"
        record_id  = @sb[:active_tab].split("settings_").last
      else
        action_url = "settings_update"
        record_id = @sb[:active_tab].split("settings_").last
        locals[:no_cancel] = true
        locals[:serialize] = true if @sb[:active_tab] == "settings_advanced"
        if @sb[:active_tab] == "settings_database"
          locals[:save_text] = "Save changes and restart the Server"
          locals[:save_confirm_text] = "Server will be restarted immediately after the changes are saved, are you sure you want to proceed?"
        end
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
      elsif %(rbac_group_tags_edit rbac_user_tags_edit).include?(@sb[:action])
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
    return locals
  end

  # Get all info for the node about to be displayed
  def get_node_info(treenodeid)
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
    when :analytics_tree   then analytics_get_info(x_node)
    when :diagnostics_tree then diagnostics_get_info(x_node)
    when :rbac_tree        then rbac_get_info(x_node)
    when :settings_tree    then settings_get_info(x_node)
    when :vmdb_tree        then db_get_info(x_node)
    end

    region_text = "[Region: #{MiqRegion.my_region.description} [#{MiqRegion.my_region.region}]]"
    @right_cell_text ||= case x_active_tree
                         when :diagnostics_tree then "Diagnostics #{region_text}"
                         when :settings_tree    then "Settings #{region_text}"
                         when :rbac_tree        then "Access Control #{region_text}"
                         when :analytics_tree   then "Analytics #{region_text}"
                         when :vmdb_tree        then "Database []"
                         end
  end

  def replace_right_cell(nodetype, replace_trees = false) # replace_trees can be an array of tree symbols to be replaced
    replace_trees = @replace_trees if @replace_trees  #get_node_info might set this
    @explorer = true
    if replace_trees
      settings_tree = settings_build_tree if replace_trees.include?(:settings)
      rbac_tree = rbac_build_tree if replace_trees.include?(:rbac)
      diagnostics_tree = diagnostics_build_tree if replace_trees.include?(:diagnostics)
      vmdb_tree = db_build_tree if replace_trees.include?(:vmdb)
      if get_vmdb_config[:product][:analytics]
        analytics_tree = analytics_build_tree if replace_trees.include?(:analytics)
      end
    end

    # Clicked on right cell record, open the tree enough to show the node, if not already showing
    if params[:action] == "x_show" && @record &&          # Showing a record
       !@in_a_form                                      # Not in a form
      existing_node = nil                     # Init var

      parent_rec = VmdbTableEvm.find_by_id(@record.vmdb_table_id)
      parents = [parent_rec, {:id=>"#{@record.vmdb_table_id}"}]
      #parents = [parent_rec]

      # Go up thru the parents and find the highest level unopened, mark all as opened along the way
      unless parents.empty? ||  # Skip if no parents or parent already open
             x_tree[:open_nodes].include?(x_build_node_id(parents.last))
        parents.reverse.each do |p|
          p_node = x_build_node_id(p)
          unless x_tree[:open_nodes].include?(p_node)
            x_tree[:open_nodes].push(p_node)
            existing_node = p_node
          end
        end
        add_nodes = tree_add_child_nodes(existing_node) # Build the new nodes hash
      end
    end
    locals = set_form_locals if @in_a_form
    if !@in_a_form
      @sb[:center_tb_filename] = center_toolbar_filename
      c_buttons, c_xml = build_toolbar_buttons_and_xml(@sb[:center_tb_filename])
    end
    build_supported_depots_for_select
    render :update do |page|
      # forcing form buttons to turn off, to prevent Abandon changes popup when replacing right cell after form button was pressed
      page << javascript_for_miq_button_visibility(false)
      if replace_trees
        if replace_trees.include?(:settings)
          self.x_node  = @new_settings_node if @new_settings_node
          page.replace("settings_tree_div", :partial=>"shared/tree",
                       :locals  => {:tree => settings_tree,
                                    :name => settings_tree.name.to_s
                       }
          )
        end
        if replace_trees.include?(:rbac)
          self.x_node  = @new_role_node if @new_role_node
          page.replace("rbac_tree_div", :partial=>"shared/tree",
                       :locals  => {:tree => rbac_tree,
                                    :name => rbac_tree.name.to_s
                       }
          )
        end
        if replace_trees.include?(:diagnostics)
          self.x_node  = @new_diagnostics_node if @new_diagnostics_node
          page.replace("diagnostics_tree_div", :partial=>"shared/tree",
                       :locals  => {:tree => diagnostics_tree,
                                    :name => diagnostics_tree.name.to_s
                       }
          )
        end
       if replace_trees.include?(:vmdb)
         @sb[:active_node][:vmdb_tree] = @new_db_node if @new_db_node
         page.replace("vmdb_tree_div", :partial=>"shared/tree",
                      :locals  => {:tree => vmdb_tree,
                                   :name => vmdb_tree.name.to_s
                      }
         )
       end
        if get_vmdb_config[:product][:analytics]
          if replace_trees.include?(:analytics)
            self.x_node  = @new_analytics_node if @new_analytics_node
            page.replace("analytics_tree_div", :partial=>"shared/tree",
                         :locals  => {:tree => analytics_tree,
                                      :name => analytics_tree.name.to_s
                         }
            )
          end
        end
        if params[:action].ends_with?("_delete") && x_node == "root"
          nodes = x_node.split("-")
          nodes.pop
          #self.x_node = nodes.join("-")
          if params[:action] == "schedule_delete"
            self.x_node = "xx-msc"
         elsif params[:action] == "ldap_region_delete"
            self.x_node = "l"
          elsif params[:action] == "zone_delete"
            self.x_node = "xx-z"
          elsif params[:action] == "ap_delete"
            self.x_node = "xx-sis"
          end
        end
      end
      case x_active_tree
        when :rbac_tree
          unless @tagging
            nodes = x_node.split("-")
            @sb[:tab_label] = case nodes.first
              when "xx"
                case nodes.last
                  when "u"
                    "Users"
                  when "g"
                    "Groups"
                  when "ur"
                    "Roles"
                end
              when "u"
                @user.name || "Users"
              when "g"
                @record && @record.id ? @record.description : (@group && @group.id ? @group.description : "Groups")
              when "ur"
                @role.name || "Roles"
              else
                "Details"
            end
          else
            @sb[:tab_label] = "Tagging"
          end
          page << "dhxLayoutB.cells('b').setText('#{escape_javascript(h(@right_cell_text))}');"
          page << "var miq_double_click = false;" # Make sure the double_click var is there
          if %w(accordion_select change_tab tree_select).include?(params[:action])
            page.replace("ops_tabs", :partial=>"all_tabs")
          elsif nodetype == "group_seq"
            page.replace("flash_msg_div", :partial => "layouts/flash_msg")
            page.replace_html("rbac_details", :partial => "ldap_seq_form")
          else
            page.replace_html(@sb[:active_tab], :partial=>"#{@sb[:active_tab]}_tab")
          end
        when :settings_tree
          case nodetype
            when "ze"     #zone edit
              #when editing zone in settings tree
              if @zone.id.blank?
                partial_div = "settings_list"
                right_cell_text = _("Adding a new %s") % ui_lookup(:model=>"Zone")
              else
                partial_div = "settings_evm_servers"
                right_cell_text = @edit ?
                  _("Editing %{model} \"%{name}\"") % {:name=>@zone.description, :model=>ui_lookup(:model=>"Zone")} :
                  _("%{model} \"%{name}\"") % {:model=>ui_lookup(:model=>"Zone"), :name=>@zone.description}
              end
              page.replace_html(partial_div, :partial=>"zone_form")
              page << "dhxLayoutB.cells('b').setText('#{escape_javascript(h(right_cell_text))}');"
            when "ce"     #category edit
              #when editing/adding category in settings tree
              page.replace_html("settings_co_categories", :partial=>"category_form")
              if !@category
                right_cell_text = _("Adding a new %s") % "Category"
              else
                right_cell_text = _("Editing %{model} \"%{name}\"") % {:name=>@category.description, :model=>"Category"}
              end
              page << "dhxLayoutB.cells('b').setText('#{escape_javascript(h(right_cell_text))}');"
            when "sie"        #scanitemset edit
              #when editing/adding scanitem in settings tree
              page.replace_html("settings_list", :partial=>"ap_form")
              if !@scan.id
                right_cell_text = _("Adding a new %s") % ui_lookup(:model=>"ScanItemSet")
              else
                right_cell_text = @edit ?
                  _("Editing %{model} \"%{name}\"") % {:name=>@scan.name, :model=>ui_lookup(:model=>"ScanItemSet")} :
                  _("%{model} \"%{name}\"") % {:model=>ui_lookup(:model=>"ScanItemSet"), :name=>@scan.name}
              end
              page << "dhxLayoutB.cells('b').setText('#{escape_javascript(h(right_cell_text))}');"
            when "se"         #schedule edit
              #when editing/adding schedule in settings tree
              page.replace_html("settings_list", :partial=>"schedule_form")
              page << "miq_cal_dateFrom = new Date(#{(Time.now - 1.month).in_time_zone(@edit[:tz]).strftime("%Y,%m,%d")});"
              page << "miq_cal_dateTo = null;"
              page << "miqBuildCalendar();"
              if !@schedule.id
                right_cell_text = _("Adding a new %s") % ui_lookup(:model=>"MiqSchedule")
              else
                right_cell_text = @edit ?
                  _("Editing %{model} \"%{name}\"") % {:name=>@schedule.name, :model=>ui_lookup(:model=>"MiqSchedule")} :
                  _("%{model} \"%{name}\"") % {:model=>ui_lookup(:model=>"MiqSchedule"), :name=>@schedule.name}
              end
              page << "dhxLayoutB.cells('b').setText('#{escape_javascript(h(right_cell_text))}');"
            when "lde"          #ldap_region edit
              #when editing/adding ldap domain in settings tree
              page.replace_html("settings_list", :partial=>"ldap_domain_form")
              if !@ldap_domain.id
                right_cell_text = _("Adding a new %s") % ui_lookup(:model=>"LdapDomain")
              else
                right_cell_text = @edit ?
                    _("Editing %{model} \"%{name}\"") % {:name=>@ldap_domain.name, :model=>ui_lookup(:model=>"LdapDomain")} :
                    _("%{model} \"%{name}\"") % {:model=>ui_lookup(:model=>"LdapDomain"), :name=>@ldap_domain.name}
              end
              page << "dhxLayoutB.cells('b').setText('#{escape_javascript(h(right_cell_text))}');"
            when "lre"          #ldap_region edit
                                #when editing/adding ldap region in settings tree
              page.replace_html("settings_list", :partial=>"ldap_region_form")
              if !@ldap_region.id
                right_cell_text = _("Adding a new %s") % ui_lookup(:model=>"LdapRegion")
              else
                right_cell_text = @edit ?
                    _("Editing %{model} \"%{name}\"") % {:name=>@ldap_region.name, :model=>ui_lookup(:model=>"LdapRegion")} :
                    _("%{model} \"%{name}\"") % {:model=>ui_lookup(:model=>"LdapRegion"), :name=>@ldap_region.name}
              end
              page << "dhxLayoutB.cells('b').setText('#{escape_javascript(h(right_cell_text))}');"
            when 'rhn'          # rhn subscription edit
                page.replace_html('settings_rhn', :partial=>"#{@sb[:active_tab]}_tab")
            else
              if %w(accordion_select change_tab tree_select).include?(params[:action]) &&
                  params[:tab_id] != "settings_advanced"
                page.replace("ops_tabs", :partial=>"all_tabs")
              elsif %w(zone_delete).include?(params[:pressed])
                page.replace("ops_tabs", :partial=>"all_tabs")
              else
                page.replace_html(@sb[:active_tab], :partial=>"#{@sb[:active_tab]}_tab")
              end
              active_id = from_cid(x_node.split("-").last)
              # server node
              if x_node.split("-").first == "svr" && @sb[:my_server_id] == active_id.to_i
                #show all the tabs if on current server node
                @temp[:selected_server] ||= MiqServer.find(@sb[:selected_server_id])  # Reread the server record
                page << "miqOneTrans = 0;"          #resetting miqOneTrans when tab loads
                page << "miqIEButtonPressed = true" if %w(save reset).include?(params[:button]) && is_browser_ie?
              elsif x_node.split("-").first.split("__")[1] == "svr" && @sb[:my_server_id] != active_id.to_i
                #show only 4 tabs if not on current server node
                @temp[:selected_server] ||= MiqServer.find(@sb[:selected_server_id])  # Reread the server record
              end
              page << "dhxLayoutB.cells('b').setText('#{escape_javascript(h(@right_cell_text))}');"
          end
        when :diagnostics_tree
          #need to refresh all_tabs for server by roles and roles by servers screen
          #to show correct buttons on screen when tree node is selected
          if %w(accordion_select change_tab explorer tree_select).include?(params[:action]) ||
             %w(diagnostics_roles_servers diagnostics_servers_roles).include?(@sb[:active_tab])
            page.replace("ops_tabs", :partial=>"all_tabs")
          elsif nodetype == "log_depot_edit"
            @right_cell_text = "Editing Log Depot settings"
            page.replace_html("diagnostics_collect_logs", :partial => "ops/log_collection")
          else
            page.replace_html(@sb[:active_tab], :partial=>"#{@sb[:active_tab]}_tab")
          end
          page << "dhxLayoutB.cells('b').setText('#{escape_javascript(h(@right_cell_text))}');"
          # zone level
          if x_node.split("-").first == "z"
            page << "miq_cal_dateFrom = null;"
            page << "miq_cal_dateTo = new Date();"
            page << "miqBuildCalendar();"
          end
        when :vmdb_tree #"root","tb", "ti","xx" # Check if vmdb root or table is selected
          # Need to replace all_tabs to show table name as tab label
          page.replace("ops_tabs", :partial=>"all_tabs")
          page << "dhxLayoutB.cells('b').setText('#{escape_javascript(h(@right_cell_text))}');"
        when :analytics_tree
          page << "dhxLayoutB.cells('b').setText('#{escape_javascript(h(@right_cell_text))}');"
          if params[:action] == "accordion_select"
            page.replace("ops_tabs", :partial=>"all_tabs")
          else
            page.replace_html("analytics_details", :partial=>"analytics_details_tab")
          end
          if %w(settings_import settings_import_tags).include?(@sb[:active_tab])
            #setting changed here to enable/disable Apply button
            @changed = @sb[:good] && @sb[:good] > 0 ? true : false
          end
          page << javascript_for_miq_button_visibility(@changed) if @in_a_form
      end

      # Handle bottom cell
      if @pages || @in_a_form
        if @pages
          page.replace_html("paging_div",:partial=>"layouts/x_pagingcontrols")
          page << javascript_hide_if_exists("form_buttons_div")
          page << javascript_show_if_exists("pc_div_1")
        elsif @in_a_form
          page.replace_html("form_buttons_div", :partial => "layouts/x_edit_buttons", :locals => locals)
          page << javascript_hide_if_exists("pc_div_1")
          page << javascript_show_if_exists("form_buttons_div")
        end
        page << "dhxLayoutB.cells('c').expand();"
      else
        page << "dhxLayoutB.cells('c').collapse();"
      end

      if c_buttons && c_xml
        page << "dhxLayoutB.cells('a').expand();"
        page << javascript_for_toolbar_reload('center_tb', c_buttons, c_xml)
        page << javascript_show_if_exists("center_buttons_div")
      else
        page << "dhxLayoutB.cells('a').collapse();"
        page << javascript_hide_if_exists("center_buttons_div")
      end

      page << "dhxLayoutB.cells('a').collapse();" if @sb[:center_tb_filename] == "blank_view_tb"

      if (@record && !@in_a_form) || (@edit && @edit[:rec_id] && @in_a_form)
        page << "miq_record_id = '#{@record ? @record.id : @edit[:rec_id]}';" # Create miq_record_id JS var, if @record is present
      else
        page << "miq_record_id = undefined;"  # reset this, otherwise it remembers previously selected id and sends up from list view when add button is pressed
      end

      if role_allows(:feature=>"ops_settings")
        page << javascript_dim("settings_tree_div", false)
      end
      if role_allows(:feature=>"ops_rbac")
        page << javascript_dim("rbac_tree_div", false)
      end
      if role_allows(:feature=>"ops_diagnostics")
        page << javascript_dim("diagnostics_tree_div", false)
      end
      if role_allows(:feature=>"ops_db")
        page << javascript_dim("vmdb_tree_div", false)
      end
      if get_vmdb_config[:product][:analytics]
        page << javascript_dim("analytics_tree_div", false)
      end

      page << "cfmeDynatree_activateNodeSilently('#{x_active_tree}', '#{x_node}');"
      page << "miqSparkleOff();"
      page << javascript_focus_if_exists('server_company')
      page << "if (miqDomElementExists('flash_msg_div')) {"
        page.replace("flash_msg_div", :partial => "layouts/flash_msg")
      page << "}"
      if @ajax_action
        page << "miqAsyncAjax('#{url_for(:action=>@ajax_action, :id=>@record)}');"
      end
    end
  end

  # Build the audit object when a profile is saved
  def build_saved_audit(record, add = false)
    name = record.respond_to?(:name) ? record.name : record.description
    msg = "[#{name}] Record #{add ? "added" : "updated"} ("
    event = "#{record.class.to_s.downcase}_record_#{add ? "add" : "update"}"
    i = 0
    @edit[:new].each_key do |k|
      if @edit[:new][k] != @edit[:current][k]
        if k.to_s.ends_with?("password2") || k.to_s.ends_with?("verify")      #do nothing
        elsif k.to_s.ends_with?("password") || k.to_s.ends_with?("_pwd")  # Asterisk out password fields
          msg = msg +  k.to_s + ":[*] to [*]"
        else
          msg = msg + ", " if i > 0
          i += 1
          if k == :members
            msg = msg +  k.to_s + ":[" + @edit[:current][k].keys.join(",") + "] to [" + @edit[:new][k].keys.join(",") + "]"
          else
            msg = msg +  k.to_s + ":[" + @edit[:current][k].to_s + "] to [" + @edit[:new][k].to_s + "]"
          end
        end
      end
    end
    msg = msg + ")"
    audit = {:event=>event, :target_id=>record.id, :target_class=>record.class.base_class.name, :userid => session[:userid], :message=>msg}
  end

  def identify_tl_or_perf_record
    identify_record(@sb[:record_id], @sb[:record_class].constantize)
  end

  def get_session_data
    @title         = "Configuration"
    @layout        = "ops"
    @tasks_options = session[:tasks_options] || ""
  end

  def set_session_data
    session[:tasks_options] = @tasks_options unless @tasks_options.nil?
  end

end
