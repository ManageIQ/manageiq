class InfraNetworkingController < ApplicationController
  before_action :check_privileges
  before_action :get_session_data

  after_action :cleanup_action
  after_action :set_session_data

  def self.model
    Switch
  end

  def self.table_name
    @table_name ||= "switch"
  end

  def show_list
    redirect_to :action => 'explorer', :flash_msg => @flash_array ? @flash_array[0][:message] : nil
  end


  def index
    redirect_to :action => 'explorer'
  end

  def show_list_old
    redirect_to :action => 'explorer', :flash_msg => @flash_array.try(:fetch_path, 0, :message)
  end

  def show(id = nil)
    return if perfmenu_click
    @explorer = true
    @display = params[:display] || "main" unless control_selected?
    @record = @switch = find_record( Switch, id || params[:id])
    return if record_no_longer_exists?(@switch)

    if !@explorer && @display == "main"
      tree_node_id = TreeBuilder.build_node_id(@record)
      session[:exp_parms] = {:display => @display, :refresh => params[:refresh], :id => tree_node_id}

      # redirect user back to where they came from if they dont have access to any of vm explorers
      # or redirect them to the one they have access to
      redirect_controller = role_allows?(:feature => "infra_networking") ? "infra_networking" : nil

      if redirect_controller
        action = "explorer"
      else
        url = request.env['HTTP_REFERER'].split('/')
        add_flash(_("User '%{username}' is not authorized to access '%{controller_name}'") %
                    {:username => current_userid, :controller_name => ui_lookup(:table => controller_name)}, :warning)
        session[:flash_msgs] = @flash_array.dup
        redirect_controller  = url[3]
        action               = url[4]
      end

      redirect_to :controller => redirect_controller,
                  :action     => action
      return
    end

    @gtl_url = "/show"

    case @display
    when "hosts"
      @view, @pages = get_view(Host, :parent => @record) # Get the records (into a view) and the paginator
      drop_breadcrumb(:name => _("%{name} (All Registered Hosts)") % {:name => @record.name},
                      :url  => "/infra_networking/x_show/#{@record.id}?display=hosts")
      @showtype = "hosts"
    when "download_pdf"
      set_summary_pdf_data
    end
    @lastaction = "show"
  end

  def button
    @edit = session[:edit]                                  # Restore @edit for adv search box
    params[:display] = @display if ["hosts"].include?(@display)  # Were we displaying sub-items

    if params[:pressed].starts_with?("host_")
      scanhosts if params[:pressed] == "host_scan"
      analyze_check_compliance_hosts if params[:pressed] == "host_analyze_check_compliance"
      check_compliance_hosts if params[:pressed] == "host_check_compliance"
      refreshhosts if params[:pressed] == "host_refresh"
      tag(Host) if params[:pressed] == "host_tag"
      assign_policies(Host) if params[:pressed] == "host_protect"
      comparemiq  if params[:pressed] == "host_compare"
      edit_record  if params[:pressed] == "host_edit"
      deletehosts if params[:pressed] == "host_delete"

      pfx = pfx_for_vm_button_pressed(params[:pressed])
      # Handle Host power buttons
      if ["host_shutdown", "host_reboot", "host_standby", "host_enter_maint_mode", "host_exit_maint_mode",
          "host_start", "host_stop", "host_reset"].include?(params[:pressed])
        powerbutton_hosts(params[:pressed].split("_")[1..-1].join("_")) # Handle specific power button
      else
        process_vm_buttons(pfx)
        return if ["host_tag", "#{pfx}_policy_sim", "host_scan", "host_refresh", "host_protect",
                   "host_compare", "#{pfx}_compare", "#{pfx}_drift", "#{pfx}_tag", "#{pfx}_retire",
                   "#{pfx}_protect", "#{pfx}_ownership", "#{pfx}_right_size",
                   "#{pfx}_reconfigure"].include?(params[:pressed]) &&
          @flash_array.nil?   # Some other screen is showing, so return

        unless ["host_edit", "#{pfx}_edit", "#{pfx}_miq_request_new", "#{pfx}_clone", "#{pfx}_migrate", "#{pfx}_publish"].include?(params[:pressed])
          @refresh_div = "main_div"
          @refresh_partial = "layouts/gtl"
          show
        end
      end
    else
      @refresh_div = "main_div" # Default div for button.rjs to refresh
    end

    if !@flash_array && !@refresh_partial # if no button handler ran, show not implemented msg
      add_flash(_("Button not yet implemented"), :error)
      @refresh_partial = "layouts/flash_msg"
      @refresh_div = "flash_msg_div"
    elsif @flash_array && @lastaction == "show"
      @switch = @record = identify_record(params[:id])
      @refresh_partial = "layouts/flash_msg"
      @refresh_div = "flash_msg_div"
    end

    if params[:pressed].ends_with?("_edit") || ["#{pfx}_miq_request_new", "#{pfx}_clone", "#{pfx}_migrate", "#{pfx}_publish"].include?(params[:pressed])
      render_or_redirect_partial(pfx)
    else
      if @refresh_div == "main_div" && @lastaction == "show_list"
        replace_gtl_main_div
      end
    end
  end

  def tree_select
    @lastaction = "explorer"
    @flash_array = nil
    self.x_active_tree = params[:tree] if params[:tree]
    self.x_node = params[:id]
    load_or_clear_adv_search
    apply_node_search_text if x_active_tree == :infra_networking_tree
    replace_right_cell
  end

  def accordion_select
    @lastaction = "explorer"
    @explorer = true

    @sb[:infra_networking_search_text] ||= {}
    @sb[:infra_networking_search_text]["#{x_active_accord}_search_text"] = @search_text

    self.x_active_accord = params[:id].sub(/_accord$/, '')
    self.x_active_tree   = "#{x_active_accord}_tree"
    get_node_info(x_node)

    @search_text = @sb[:infra_networking_search_text]["#{x_active_accord}_search_text"]

    load_or_clear_adv_search
    replace_right_cell(x_node)
  end

  def load_or_clear_adv_search
    adv_search_build("InfraNetworking")
    session[:edit] = @edit
    @explorer = true

    if x_node == "root"
      listnav_search_selected(0)
    else
      @nodetype, id = parse_nodetype_and_id(valid_active_node(x_node))
    end
  end

  def x_show
    @explorer = true
    @storage = @record = identify_record(params[:id], Switch)
    respond_to do |format|
      format.js do                  # AJAX, select the node
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
      format.any { head :not_found }  # Anything else, just send 404
    end
  end

  def tree_record
    @record =
      case x_active_tree
        when :infra_networking_tree then infra_networking_tree_rec
      end
  end

  def infra_networking_tree_rec
    nodes = x_node.split('-')
    case nodes.first
      when "root", 'e' then find_record(ExtManagementSystem, params[:id])
      when "h" then find_record(Host, params[:id])
      when "c"   then find_record(Cluster, params[:id])
      when "sw" then find_record(Switch, params[:id])
    end
  end

  def show_record(_id = nil)
    @display    = params[:display] || "main" unless control_selected?
    @lastaction = "show"
    @showtype   = "config"

    if @record.nil?
      add_flash(_("Error: Record no longer exists in the database"), :error)
      if request.xml_http_request? && params[:id]  # Is this an Ajax request clicking on a node that no longer exists?
        @delete_node = params[:id]                 # Set node to be removed from the tree
      end
      return
    end

    if @record.kind_of?(Switch)
      rec_cls = "#{@record.class.to_s}"
    end
    return unless %w(download_pdf main).include?(@display)
    @showtype     = "main"
    @button_group = "infra_networking_#{rec_cls}"
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

    build_accordions_and_trees

    params.instance_variable_get(:@parameters).merge!(session[:exp_parms]) if session[:exp_parms]
    session.delete(:exp_parms)
    @in_a_form = false

    if params[:id]
      nodetype, id = params[:id].split("-")
      @reselect_node = self.x_node = "#{nodetype}-#{to_cid(id)}"
      get_node_info(x_node)
    end
    render :layout => "application"
  end

  def tree_autoload_dynatree
    @view ||= session[:view]
    x_tree_init(:infra_networking_tree, :infra_networking, nil)
    super
  end

  private ###########


  def hosts_list
    condition         = nil
    label             = _("%{name} (All %{titles})" % {:name => @switch.name, :titles => title_for_hosts})
    breadcrumb_suffix = ""
    @no_checkboxes = true

    host_service_group_name = params[:host_service_group_name]
    if host_service_group_name
      case params[:status]
        when 'running'
          hosts_filter =  @switch.host_ids_with_running_service_group(host_service_group_name)
          label        = _("Hosts with running %{name}") % {:name => host_service_group_name}
        when 'failed'
          hosts_filter =  @switch.host_ids_with_failed_service_group(host_service_group_name)
          label        = _("Hosts with failed %{name}") % {:name => host_service_group_name}
        when 'all'
          hosts_filter = @switch.host_ids_with_service_group(host_service_group_name)
          label        = _("All %{titles} with %{name}") % {:titles => title_for_hosts, :name => host_service_group_name}
      end

      if hosts_filter
        condition = ["hosts.id IN (#{hosts_filter.to_sql})"]
        breadcrumb_suffix = "&host_service_group_name=#{host_service_group_name}&status=#{params[:status]}"
      end
    end

    return label, condition, breadcrumb_suffix
  end

  def display_node(id, model)
    if @record.nil?
      self.x_node = "root"
      get_node_info("root")
    else
      show_record(from_cid(id))
      model_string = ui_lookup(:model => @record.class.to_s)
      @right_cell_text = _("%{model} \"%{name}\"") % {:name => @record.name, :model => model_string}
    end
  end

  def features
    [{:role     => "infra_networking",
      :role_any => true,
      :name     => :infra_networking,
      :title    => _("Switches")},
    ].map do |hsh|
      ApplicationController::Feature.new_with_hash(hsh)
    end
  end

  def build_infra_networking_tree(type, name)
    tree = case name
           when :infra_networking_tree
               TreeBuilderConfigurationManager.new(name, type, @sb)
           end
    instance_variable_set :"@#{name}", tree.tree_nodes
    tree
  end

  def get_node_info(treenodeid)
    @sb[:action] = nil
    @nodetype, id = parse_nodetype_and_id(valid_active_node(treenodeid))

    model = TreeBuilder.get_model_for_prefix(@nodetype)
    if model == "Hash"
      model = TreeBuilder.get_model_for_prefix(id)
      id = nil
    end

    case model
    when "EmsFolder"
      emsfolder_node(id, EmsFolder)
    when  "ExtManagementSystem"
      provider_switches_list(id, ExtManagementSystem)
    when  "Host"
      host_switches_list(id, Host)
    when "EmsCluster"
      cluster_switches_list(id, EmsCluster)
    when "Switch"

      dvswitch_node(id, Switch)
    when "MiqSearch"
      miq_search_node
    else
      default_node
    end
    @right_cell_text += @edit[:adv_search_applied][:text] if x_tree && @edit && @edit[:adv_search_applied]

    if @edit && @edit.fetch_path(:adv_search_applied, :qs_exp) # If qs is active, save it in history
      x_history_add_item(:id     => x_node,
                         :qs_exp => @edit[:adv_search_applied][:qs_exp],
                         :text   => @right_cell_text)
    else
      x_history_add_item(:id => treenodeid, :text => @right_cell_text)  # Add to history pulldown array
    end
  end

  def dvswitches_list(id, model)
    return dvswitch_node(id, model) if id
    if x_active_tree == :infra_networking_tree
      options = {:model => "Switch", :where_clause => ["shared = true"]}
      @no_checkboxes = true
      @right_cell_text = _("All %{title}") % {:title => model_to_name(model)}
      process_show_list(options)
    end
  end

  def dvswitch_node(id, model)
    @record = @switch_record = find_record(model, id) if model
    display_node(id, model)
  end

  def host_switches_list(id, model)
    @record = @host_record = find_record(model, id) if model

    if @host_record.nil?
      self.x_node = "root"
      get_node_info("root")
    else
      @no_checkboxes = true
      options = {:model => "Switch", :where_clause => ["shared = true and id in(?)", @host_record.switches.pluck(:id)]}
      process_show_list(options)
      @showtype        = 'main'
      @pages           = nil
      @right_cell_text = _("Switches for %{model} \"%{name}\"") % {:model => model, :name => @host_record.name}
    end
  end

  def cluster_switches_list(id, model)
    @record = @cluster_record = find_record(model, id) if model

    if @cluster_record.nil?
      self.x_node = "root"
      get_node_info("root")
    else
      @no_checkboxes = true
      hosts = @cluster_record.hosts
      switch_ids = hosts.collect{|host| host.switches.pluck(:id)}
      options = {:model => "Switch", :where_clause => ["shared = true and id in(?)", switch_ids.flatten.uniq]}
      process_show_list(options)
      @showtype        = 'main'
      @pages           = nil
      @right_cell_text = _("Switches for %{model} \"%{name}\"") % {:model => model, :name => @cluster_record.name}
    end
  end


  def provider_switches_list(id, model)
    @record = @provider_record = find_record(model, id) if model

    if @provider_record.nil?
      self.x_node = "root"
      get_node_info("root")
    else
      @no_checkboxes = true
      hosts = Host.where(:ems_id => @provider_record.id)
      switch_ids = hosts.collect{|host| host.switches.pluck(:id)}
      options = {:model => "Switch", :where_clause => ["shared = true and id in(?)", switch_ids.flatten.uniq]}
      process_show_list(options)
      @showtype        = 'main'
      @pages           = nil
      @right_cell_text = _("Switches for %{model} \"%{name}\"") % {:model => model, :name => @provider_record.name}
    end
  end

  def miq_search_node
    options = {:model => "Switch"}
    process_show_list(options)
    @right_cell_text = _("All %{title} ") % {:title => ui_lookup(:ui_title => model)}
  end

  def default_node
    return unless x_node == "root"
    options = {:model => "Switch", :where_clause => ["shared = true"]}
    @no_checkboxes = true
    process_show_list(options)
    @right_cell_text = _("All Switches")
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
    presenter.update(:main_div, r[:partial => 'form', :locals => {:controller => 'infra_networking'}])
    update_title(presenter)
    rebuild_toolbars(false, presenter)
    handle_bottom_cell(presenter, r)

    render :json => presenter.for_render
  end

  def render_tagging_form
    return if %w(cancel save).include?(params[:button])
    @in_a_form = true
    @right_cell_text = _("Edit Tags")
    clear_flash_msg
    presenter, r = rendering_objects
    update_tagging_partials(presenter, r)
    update_title(presenter)
    rebuild_toolbars(false, presenter)
    handle_bottom_cell(presenter, r)

    render :json => presenter.for_render
  end

  def update_tree_and_render_list(replace_trees)
    @explorer = true
    get_node_info(x_node)
    presenter, r = rendering_objects
    replace_explorer_trees(replace_trees, presenter, r)

    presenter.update(:main_div, r[:partial => 'layouts/x_gtl'])
    rebuild_toolbars(false, presenter)
    handle_bottom_cell(presenter, r)

    render :json => presenter.for_render
  end

  def replace_right_cell(replace_trees = [], action = nil)
    return if @in_a_form
    @explorer = true

    @sb[:action] = action unless action.nil?
    if @sb[:action] || params[:display]
      partial, action, @right_cell_text = set_right_cell_vars # Set partial name, action and cell header
    end
    @in_a_form = false

    trees = {}
    if replace_trees
      trees[:infra_networking_tree] = build_infra_networking_tree(:infra_networking,
                                                                  :infra_networking_tree) if replace_trees.include?(:infra_networking_tree)
    end
    record_showing = leaf_record
    presenter, r = rendering_objects
    update_partials(record_showing, presenter, r)
    replace_search_box(presenter, r)
    handle_bottom_cell(presenter, r)
    replace_trees_by_presenter(presenter, trees)
    rebuild_toolbars(record_showing, presenter)
    presenter[:right_cell_text] = @right_cell_text
    presenter[:osf_node] = x_node  # Open, select, and focus on this node

    render :json => presenter.for_render
  end

  # set partial name and cell header for edit screens
  def set_right_cell_vars
    name = @record ? @record.name.to_s.gsub(/'/, "\\\\'") : "" # If record, get escaped name
    table = request.parameters["controller"]
    if ["details"].include?(@showtype)
      partial = "layouts/x_gtl"
    elsif @showtype == "item"
      partial = "layouts/item"
    else
      partial = "#{@showtype}"
    end
    if @showtype == "item"
      header = _("%{action} \"%{item_name}\" for %{switch} \"%{name}\"") % {
        :switch         => ui_lookup(:table => table),
        :name           => name,
        :item_name      => @item.name,
        :action         => action_type(@sb[:action], 1)
      }
      x_history_add_item(:id => x_node, :text => header, :action => @sb[:action], :item => @item.id)
    else
      header = _("\"%{action}\" for %{switch} \"%{name}\"") % {
        :vm_or_template => ui_lookup(:table => table),
        :name           => name,
        :action         => action_type(@sb[:action], 2)
      }
      if @display && @display != "main"
        x_history_add_item(:id => x_node, :text => header, :display => @display)
      else
        x_history_add_item(:id => x_node, :text => header, :action => @sb[:action]) if @sb[:action] != "drift_history"
      end
    end
    action = nil
    return partial, action, header
  end


  def leaf_record
    get_node_info(x_node)
    @delete_node = params[:id] if @replace_trees
    type, _id = parse_nodetype_and_id(x_node)
    type && %w(Switch).include?(TreeBuilder.get_model_for_prefix(type))
  end


  def dvswitch_record?(node = x_node)
    type, _id = node.split("-")
    type && ["Switch"].include?(TreeBuilder.get_model_for_prefix(type))
  end

  def search_text_type(node)
    return "dvswitch" if dvswitch_record?(node)
    node
  end

  def apply_node_search_text
    setup_search_text_for_node
    previous_nodetype = search_text_type(@sb[:infra_networking_search_text][:previous_node])
    current_nodetype  = search_text_type(@sb[:infra_networking_search_text][:current_node])

    @sb[:infra_networking_search_text]["#{previous_nodetype}_search_text"] = @search_text
    @search_text = @sb[:infra_networking_search_text]["#{current_nodetype}_search_text"]
    @sb[:infra_networking_search_text]["#{x_active_accord}_search_text"] = @search_text
  end

  def setup_search_text_for_node
    @sb[:infra_networking_search_text] ||= {}
    @sb[:infra_networking_search_text][:current_node] ||= x_node
    @sb[:infra_networking_search_text][:previous_node] = @sb[:infra_networking_search_text][:current_node]
    @sb[:infra_networking_search_text][:current_node] = x_node
  end

  def update_partials(record_showing, presenter, r)
    if record_showing && valid_switch_record?(@record)
      presenter.hide(:form_buttons_div)
      path_dir = "infra_networking"
      presenter.update(:main_div, r[:partial => "#{path_dir}/main",
                                    :locals  => {:controller => 'infra_networking'}])
    else
      presenter.update(:main_div, r[:partial => 'layouts/x_gtl'])
    end
  end

  def action_type(type, amount)
    case type
      when "hosts"
        n_("Host", "Hosts", amount)
      else
        amount > 1 ? type.titleize : type.titleize.singularize
    end
  end

  def replace_search_box(presenter, r)
    # Replace the searchbox
    presenter.replace(:adv_searchbox_div,
                      r[:partial => 'layouts/x_adv_searchbox',
                        :locals  => {:nameonly => x_active_tree == :infra_networking_tree}])

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
    center_tb = "blank_view_tb"
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
    presenter[:clear_search_toggle] = clear_search_status

    presenter.hide(:blocker_div) unless @edit && @edit[:adv_search_open]
    presenter.hide(:quicksearchbox)
    presenter[:hide_modal] = true

    presenter.lock_tree(x_active_tree, @in_a_form)
  end

  def display_adv_searchbox
    !(@infra_networking_record || @in_a_form )
  end

  def clear_flash_msg
    @flash_array = nil if params[:button] != "reset"
  end

  def breadcrumb_name(_model)
    "#{ui_lookup(:model => 'Switch')}"
  end

  def list_row_id(row)
    to_cid(row['id'])
  end

  def valid_switch_record?(switch_record)
    switch_record.try(:id)
  end

  def process_show_list(options = {})
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
