class StorageController < ApplicationController
  include_concern 'StorageD'
  include_concern 'StoragePod'

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def show_list
    redirect_to :action => 'explorer', :flash_msg => @flash_array ? @flash_array[0][:message] : nil
  end

  def show_new(id = nil)
    @flash_array = [] if params[:display]
    @sb[:action] = nil

    @display = params[:display] || "main"
    @lastaction = "show"
    @showtype = "config"
    @record = find_record( Storage, id || params[:id])
    return if record_no_longer_exists?(@record)

    @explorer = true if request.xml_http_request? # Ajax request means in explorer

    @gtl_url = "/show"
    set_summary_pdf_data if "download_pdf" == @display
  end

  def show(record = nil)
    return if perfmenu_click?
    @display = params[:display] || "main" unless control_selected?
    @record = @storage = find_record(Storage, record || params[:id])
    return if record_no_longer_exists?(@storage)

    if !@explorer && @display == "main"
      tree_node_id = TreeBuilder.build_node_id(@record)
      session[:exp_parms] = {:display => @display, :refresh => params[:refresh], :id => tree_node_id}

      # redirect user back to where they came from if they dont have access to any of vm explorers
      # or redirect them to the one they have access to
      redirect_controller = role_allows?(:feature => "storage") ? "storage" : nil

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
    when "all_miq_templates", "all_vms"
      title, kls = (@display == "all_vms" ? ["VMs", Vm] : ["Templates", MiqTemplate])
      drop_breadcrumb(:name => _("%{name} (All Registered %{title})") % {:name => @storage.name, :title => title},
                      :url  => "/storage/x_show/#{@storage.id}?display=#{@display}")
      @view, @pages = get_view(kls, :parent => @storage, :association => @display)  # Get the records (into a view) and the paginator
      @showtype = @display

    when "hosts"
      @view, @pages = get_view(Host, :parent => @storage) # Get the records (into a view) and the paginator
      drop_breadcrumb(:name => _("%{name} (All Registered Hosts)") % {:name => @storage.name},
                      :url  => "/storage/x_show/#{@storage.id}?display=hosts")
      @showtype = "hosts"

    when "download_pdf", "main", "summary_only"
      get_tagdata(@storage)
      session[:vm_summary_cool] = (@settings[:views][:vm_summary_cool] == "summary")
      @summary_view = session[:vm_summary_cool]
      drop_breadcrumb({:name => ui_lookup(:tables => "storages"), :url => "/storage/show_list?page=#{@current_page}&refresh=y"}, true)
      drop_breadcrumb(:name => "%{name} (Summary)" % {:name => @storage.name},
                      :url  => "/storage/x_show/#{@storage.id}?display=main")
      @showtype = "main"
      set_summary_pdf_data if ["download_pdf", "summary_only"].include?(@display)

    when "performance"
      @showtype = "performance"
      drop_breadcrumb(:name => _("%{name} Capacity & Utilization") % {:name => @storage.name},
                      :url  => "/storage/x_show/#{@storage.id}?display=#{@display}&refresh=n")
      perf_gen_init_options               # Intialize perf chart options, charts will be generated async

    when "storage_extents"
      drop_breadcrumb(:name => _(" (All %{tables})") % {:name   => @storage.name,
                                                        :tables => ui_lookup(:tables => "cim_base_storage_extent")},
                      :url  => "/storage/x_show/#{@storage.id}?display=storage_extents")
      @view, @pages = get_view(CimBaseStorageExtent, :parent => @storage, :parent_method => :base_storage_extents)  # Get the records (into a view) and the paginator
      @showtype = "storage_extents"

    when "ontap_storage_systems"
      drop_breadcrumb(:name => _("%{name} (All %{tables})") % {:name   => @storage.name,
                                                               :tables => ui_lookup(:tables => "ontap_storage_system")},
                      :url  => "/storage/x_show/#{@storage.id}?display=ontap_storage_systems")
      @view, @pages = get_view(OntapStorageSystem, :parent => @storage, :parent_method => :storage_systems) # Get the records (into a view) and the paginator
      @showtype = "ontap_storage_systems"

    when "ontap_storage_volumes"
      drop_breadcrumb(:name => _("%{name} (All %{tables})") % {:name   => @storage.name,
                                                               :tables => ui_lookup(:tables => "ontap_storage_volume")},
                      :url  => "/storage/x_show/#{@storage.id}?display=ontap_storage_volumes")
      @view, @pages = get_view(OntapStorageVolume, :parent => @storage, :parent_method => :storage_volumes) # Get the records (into a view) and the paginator
      @showtype = "ontap_storage_volumes"

    when "ontap_file_shares"
      drop_breadcrumb(:name => _("%{name} (All %{tables})") % {:name   => @storage.name,
                                                               :tables => ui_lookup(:tables => "ontap_file_share")},
                      :url  => "/storage/x_show/#{@storage.id}?display=ontap_file_shares")
      @view, @pages = get_view(OntapFileShare, :parent => @storage, :parent_method => :file_shares) # Get the records (into a view) and the paginator
      @showtype = "ontap_file_shares"
    end
    @lastaction = "show"
  end


  # handle buttons pressed on the button bar
  def button
    @edit = session[:edit]                                  # Restore @edit for adv search box
    params[:display] = @display if %w(all_vms vms hosts).include?(@display) # Were we displaying vms or hosts

    if params[:pressed].starts_with?("vm_", # Handle buttons from sub-items screen
                                     "miq_template_",
                                     "guest_",
                                     "host_")

      scanhosts if params[:pressed] == "host_scan"
      analyze_check_compliance_hosts if params[:pressed] == "host_analyze_check_compliance"
      check_compliance_hosts if params[:pressed] == "host_check_compliance"
      refreshhosts   if params[:pressed] == "host_refresh"
      tag(Host) if params[:pressed] == "host_tag"
      assign_policies(Host) if params[:pressed] == "host_protect"
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
                   "#{pfx}_compare", "#{pfx}_tag", "#{pfx}_protect", "#{pfx}_retire",
                   "#{pfx}_ownership", "#{pfx}_right_size", "#{pfx}_reconfigure"].include?(params[:pressed]) &&
                  @flash_array.nil?   # Tag screen is showing, so return

        unless ["host_edit", "#{pfx}_edit", "#{pfx}_miq_request_new", "#{pfx}_clone", "#{pfx}_migrate", "#{pfx}_publish"].include?(params[:pressed])
          @refresh_div = "main_div"
          @refresh_partial = "layouts/gtl"
          show
          @display = "vms"
        end
      end
    else
      @refresh_div = "main_div" # Default div for button.rjs to refresh
      refreshstorage if params[:pressed] == "storage_refresh"
      tag(Storage) if params[:pressed] == "storage_tag"
      scanstorage if params[:pressed] == "storage_scan"
      deletestorages if params[:pressed] == "storage_delete"
      custom_buttons if params[:pressed] == "custom_button"
    end

    return if ["custom_button"].include?(params[:pressed])    # custom button screen, so return, let custom_buttons method handle everything
    return if ["storage_tag"].include?(params[:pressed]) && @flash_array.nil?   # Tag screen showing, so return
    if !@flash_array && !@refresh_partial # if no button handler ran, show not implemented msg
      add_flash(_("Button not yet implemented"), :error)
      @refresh_partial = "layouts/flash_msg"
      @refresh_div = "flash_msg_div"
    elsif @flash_array && @lastaction == "show"
      @storage = @record = identify_record(params[:id])
      @refresh_partial = "layouts/flash_msg"
      @refresh_div = "flash_msg_div"
    end

    if !@flash_array.nil? && params[:pressed] == "storage_delete" && @single_delete
      javascript_redirect :action => 'show_list', :flash_msg => @flash_array[0][:message] # redirect to build the retire screen
    elsif params[:pressed].ends_with?("_edit") || ["#{pfx}_miq_request_new", "#{pfx}_clone",
                                                   "#{pfx}_migrate", "#{pfx}_publish"].include?(params[:pressed])
      render_or_redirect_partial(pfx)
    else
      if !flash_errors? && @refresh_div == "main_div" && @lastaction == "show_list"
        replace_gtl_main_div
      else
        javascript_flash
      end
    end
  end

  def files
    show_association('files', _('All Files'), 'storage_files', :storage_files, StorageFile, 'files')
  end

  def disk_files
    show_association('disk_files',
                     _('VM Provisioned Disk Files'),
                     'storage_disk_files',
                     :storage_files,
                     StorageFile,
                     'disk_files')
  end

  def snapshot_files
    show_association('snapshot_files',
                     _('VM Snapshot Files'),
                     'storage_snapshot_files',
                     :storage_files,
                     StorageFile,
                     'snapshot_files')
  end

  def vm_ram_files
    show_association('vm_ram_files',
                     _('VM Memory Files'),
                     'storage_memory_files',
                     :storage_files, StorageFile,
                     'vm_ram_files')
  end

  def vm_misc_files
    show_association('vm_misc_files',
                     _('Other VM Files'),
                     'storage_other_vm_files',
                     :storage_files, StorageFile,
                     'vm_misc_files')
  end

  def debris_files
    show_association('debris_files',
                     _('Non-VM Files'),
                     'storage_non_vm_files',
                     :storage_files, StorageFile,
                     'debris_files')
  end

  # gather up the storage records from the DB
  def get_storages
    page = params[:page].nil? ? 1 : params[:page].to_i
    @current_page = page
    @items_per_page = @settings[:perpage][@gtl_type.to_sym]   # Get the per page setting for this gtl type
    @storage_pages, @storages = paginate(:storages, :per_page => @items_per_page, :order => @col_names[get_sort_col] + " " + @sortdir)
  end

  def accordion_select
    @lastaction = "explorer"
    @explorer = true

    @sb[:storage_search_text] ||= {}
    @sb[:storage_search_text]["#{x_active_accord}_search_text"] = @search_text

    self.x_active_accord = params[:id].sub(/_accord$/, '')
    self.x_active_tree   = "#{x_active_accord}_tree"
    get_node_info(x_node)

    @search_text = @sb[:storage_search_text]["#{x_active_accord}_search_text"]

    load_or_clear_adv_search
    replace_right_cell(:nodetype => x_node)
  end

  def load_or_clear_adv_search
    adv_search_build("Storage")
    session[:edit] = @edit
    @explorer = true

    if x_tree[:type] != :storage || x_node == "root"
      listnav_search_selected(0)
    else
      @nodetype, id = parse_nodetype_and_id(valid_active_node(x_node))

      if x_tree[:type] == :storage && (@nodetype == "root" || @nodetype == "ms")
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
    @storage = @record = identify_record(params[:id], Storage)
    generic_x_show
  end

  def tree_select
    @lastaction = "explorer"
    self.x_active_tree = params[:tree] if params[:tree]
    self.x_node        = params[:id]

    load_or_clear_adv_search
    apply_node_search_text if x_active_tree == :storage_tree
    replace_right_cell(:nodetype => x_node)
  end

  def tree_record
    if x_active_tree == :storage_tree
      storage_tree_rec
    elsif x_active_tree == :storage_pod_tree
      storage_pod_tree_rec
    end
  end

  def storage_tree_rec
    nodes = x_node.split('-')
    case nodes.first
    when "root" then find_record(Storage, params[:id])
    when "ds"   then find_record(Storage, params[:id])
    when "xx" then
      case nodes.second
      when "ds"   then find_record(Storage, params[:id])
      end
    end
  end

  def storage_pod_tree_rec
    nodes = x_node.split('-')
    case nodes.first
    when "xx"  then @record = find_record(Storage, params[:id])
    when "dsc" then @storage_record = find_record(EmsFolder, from_cid(params[:id]))
    end
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

    if @record.class.base_model.to_s == "Storage"
      rec_cls = @record.class.base_model.to_s.underscore
    end
    return unless %w(download_pdf main).include?(@display)
    @showtype = "main"
    @button_group = "storage_pod_#{rec_cls}" if x_active_accord == :storage_pod
    @button_group = "storage_#{rec_cls}" if x_active_accord == :storage
  end


  def explorer
    @breadcrumbs = []
    @explorer = true
    @lastaction = "explorer"

    # if AJAX request, replace right cell, and return
    if request.xml_http_request?
      replace_right_cell
      return
    end

    params.instance_variable_get(:@parameters).merge!(session[:exp_parms]) if session[:exp_parms]  # Grab any explorer parm overrides
    session.delete(:exp_parms)
    @in_a_form = false
    if params[:id]  # If a tree node id came in, show in one of the trees
      nodetype, id = params[:id].split("-")
      # treebuilder initializes x_node to root first time in locals_for_render,
      # need to set this here to force & activate node when link is clicked outside of explorer.
      self.x_active_tree = :storage_tree
      self.x_node = @reselect_node = "#{nodetype}-#{to_cid(id)}"
    end

    build_accordions_and_trees
    @lastaction = "explorer" # restore the explorer layout, which was changed by process_show_list() to "show_list"

    render :layout => "application"
  end

  def tagging
    assert_privileges("storage_tag") if x_active_accord == :storage
    tagging_edit('Storage', false)
    render_tagging_form
  end

  def storage_delete
    deletestorages
  end

  def features
    [{:role     => "storage",
      :role_any => true,
      :name     => :storage,
      :title    => _("Datastores")},
     {:role     => "storage_pod",
      :role_any => true,
      :name     => :storage_pod,
      :title    => _("Datastore Clusters")},
    ].map do |hsh|
      ApplicationController::Feature.new_with_hash(hsh)
    end
  end

  def get_node_info(node)
    node = valid_active_node(node)
    case x_active_tree
    when :storage_tree     then storage_get_node_info(node)
    when :storage_pod_tree then storage_pod_get_node_info(node)
    end
    @right_cell_text += @edit[:adv_search_applied][:text] if x_tree && x_tree[:type] == :storage && @edit && @edit[:adv_search_applied]

    if @edit && @edit.fetch_path(:adv_search_applied, :qs_exp) # If qs is active, save it in history
      x_history_add_item(:id     => x_node,
                         :qs_exp => @edit[:adv_search_applied][:qs_exp],
                         :text   => @right_cell_text)
    else
      x_history_add_item(:id => node, :text => @right_cell_text)  # Add to history pulldown array
    end
  end

  def leaf_record
    get_node_info(x_node)
    @delete_node = params[:id] if @replace_trees
    type, _id = parse_nodetype_and_id(x_node)
    type && ["Storage"].include?(TreeBuilder.get_model_for_prefix(type))
  end

  def storage_record?(node = x_node)
    type, _id = parse_nodetype_and_id(node)
    type && ["Storage"].include?(TreeBuilder.get_model_for_prefix(type))
  end

  def valid_storage_record?(record)
    record.try(:id)
  end

  def replace_right_cell(options = {})
    # FIXME: nodetype passed here, but not used
    _nodetype, replace_trees = options.values_at(:nodetype, :replace_trees)
    replace_trees = @replace_trees if @replace_trees  # get_node_info might set this
    # FIXME
    @explorer = true

    if params[:action] == 'x_button'&& params[:pressed] == 'storage_tag'
      tagging
      return
    end
    return if @in_a_form
    record_showing = leaf_record

    trees = {}
    if replace_trees
      trees[:storage]     = storage_build_tree     if replace_trees.include?(:storage)
      trees[:storage_pod] = storage_pod_build_tree if replace_trees.include?(:storage_pod)
    end
    presenter, r = rendering_objects
    update_partials(record_showing, presenter, r)
    replace_search_box(presenter, r)
    handle_bottom_cell(presenter, r)
    replace_trees_by_presenter(presenter, trees)
    rebuild_toolbars(record_showing, presenter)
    case x_active_tree
      when :storage_tree
        presenter.update(:main_div, r[:partial => "storage_list"])
      when :storage_pod_tree
        presenter.update(:main_div, r[:partial => "storage_pod_list"])
    end
    presenter[:right_cell_text] = @right_cell_text
    presenter[:clear_gtl_list_grid] = @gtl_type && @gtl_type != 'list'
    presenter[:osf_node] = x_node # Open, select, and focus on this node

    render :json => presenter.for_render
  end

  def search_text_type(node)
    return "storage" if storage_record?(node)
    node
  end

  def apply_node_search_text
    setup_search_text_for_node
    previous_nodetype = search_text_type(@sb[:storage_search_text][:previous_node])
    current_nodetype = search_text_type(@sb[:storage_search_text][:current_node])

    @sb[:storage_search_text]["#{previous_nodetype}_search_text"] = @search_text
    @search_text = @sb[:storage_search_text]["#{current_nodetype}_search_text"]
    @sb[:storage_search_text]["#{x_active_accord}_search_text"] = @search_text
  end

  def setup_search_text_for_node
    @sb[:storage_search_text] ||= {}
    @sb[:storage_search_text][:current_node] ||= x_node
    @sb[:storage_search_text][:previous_node] = @sb[:storage_search_text][:current_node]
    @sb[:storage_search_text][:current_node] = x_node
  end

  def update_partials(record_showing, presenter, r)
    if record_showing
      get_tagdata(@record)
      presenter.hide(:form_buttons_div)
      path_dir = "storage"
      presenter.update(:main_div, r[:partial => "#{path_dir}/main",
                                    :locals => {:controller => 'storage'}])
    elsif valid_storage_record?(@record)
      presenter.hide(:form_buttons_div)
      presenter.update(:main_div, r[:partial => "storage_list",
                                    :locals  => {:controller => 'storage'}])
    else
      presenter.update(:main_div, r[:partial => 'layouts/x_gtl'])
    end
  end

  def replace_search_box(presenter, r)
    # Replace the searchbox
    presenter.replace(:adv_searchbox_div,
                      r[:partial => 'layouts/x_adv_searchbox',
                        :locals  => {:nameonly => x_active_tree == :storage}])

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

  def rendering_objects
    presenter = ExplorerPresenter.new(
      :active_tree => x_active_tree,
      :delete_node => @delete_node,
    )
    r = proc { |opts| render_to_string(opts) }
    return presenter, r
  end

  def render_tagging_form
    return if %w(cancel save).include?(params[:button])
    @in_a_form = true
    @right_cell_text = _("Edit Tags for Datastore")
    clear_flash_msg
    presenter, r = rendering_objects
    update_tagging_partials(presenter, r)
    # update_title(presenter)
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

  def rebuild_toolbars(record_showing, presenter)
    c_tb = build_toolbar(center_toolbar_filename) unless @in_a_form
    h_tb = build_toolbar('x_history_tb')
    v_tb = build_toolbar('x_gtl_view_tb') unless record_showing || (x_active_tree == :storage_pod_tree && x_node == 'root') || @in_a_form

    presenter.reload_toolbars(:history => h_tb, :center => c_tb, :view => v_tb)
    presenter.set_visibility(h_tb.present? || c_tb.present? || v_tb.present?, :toolbar)
    presenter[:record_id] = @record.try(:id)

    # Hide/show searchbox depending on if a list is showing
    presenter.set_visibility(display_adv_searchbox, :adv_searchbox_div)
    presenter[:clear_search_toggle] = clear_search_status

    presenter.hide(:blocker_div) unless @edit && @edit[:adv_search_open]
    presenter.hide(:quicksearchbox)
    presenter[:hide_modal] = true

    presenter.lock_tree(x_active_tree, @in_a_form)
  end

  def display_adv_searchbox
    !(@in_a_form || (x_active_tree == :storage_tree && @record) || (x_active_tree == :storage_pod_tree && (x_node == 'root' || @storage)))
  end

  def breadcrumb_name(_model)
    _("Datastores")
  end

  def tagging_explorer_controller?
    @explorer
  end

  def storage_scan
    scanstorage
  end

  private

  def get_session_data
    @title      = _("Storage")
    @layout     = "storage"
    @lastaction = session[:storage_lastaction]
    @display    = session[:storage_display]
    @filters    = session[:storage_filters]
    @catinfo    = session[:storage_catinfo]
    @showtype   = session[:storage_showtype]
  end

  def set_session_data
    session[:storage_lastaction] = @lastaction
    session[:storage_display]    = @display unless @display.nil?
    session[:storage_filters]    = @filters
    session[:storage_catinfo]    = @catinfo
    session[:storage_showtype]   = @showtype
  end

  menu_section :inf
end
