require 'yaml'

class ReportController < ApplicationController
  include_concern 'Dashboards'
  include_concern 'Menus'
  include_concern 'Reports'
  include_concern 'SavedReports'
  include_concern 'Schedules'
  include_concern 'Widgets'

  include ReportHelper

  before_action :check_privileges
  before_action :get_session_data
  after_action  :cleanup_action
  after_action  :set_session_data
  layout 'application', :except => [:render_txt, :render_csv, :render_pdf]

  def index
    @title = "Reports"
    redirect_to :action => "show"
  end

  def export_field_changed
    @sb[:choices_chosen] = params[:choices_chosen] ? params[:choices_chosen].split(',') : []
    render :nothing => true
  end

  REPORT_X_BUTTON_ALLOWED_ACTIONS = {
    'miq_report_copy'             => :miq_report_copy,
    'miq_report_delete'           => :miq_report_delete,
    'miq_report_edit'             => :miq_report_edit,
    'miq_report_new'              => :miq_report_new,
    'miq_report_run'              => :miq_report_run,
    'miq_report_schedule_add'     => :miq_report_schedule_add,
    'miq_report_schedule_edit'    => :miq_report_schedule_edit,
    'miq_report_schedule_delete'  => :miq_report_schedule_delete,
    'miq_report_schedule_enable'  => :miq_report_schedule_enable,
    'miq_report_schedule_disable' => :miq_report_schedule_disable,
    'miq_report_schedule_run_now' => :miq_report_schedule_run_now,
    'render_report_csv'           => :render_report_csv,
    'render_report_pdf'           => :render_report_pdf,
    'render_report_txt'           => :render_report_txt,
    'saved_report_delete'         => :saved_report_delete,
    'db_new'                      => :db_new,
    'db_edit'                     => :db_edit,
    'db_delete'                   => :db_delete,
    'db_seq_edit'                 => :db_seq_edit,
    'widget_refresh'              => :widget_refresh,
    'widget_new'                  => :widget_new,
    'widget_edit'                 => :widget_edit,
    'widget_copy'                 => :widget_copy,
    'widget_delete'               => :widget_delete,
    'widget_generate_content'     => :widget_generate_content,
  }.freeze

  # handle buttons pressed on the center buttons toolbar
  def x_button
    @sb[:action] = action = params[:pressed]

    raise ActionController::RoutingError.new('invalid button action') unless
      REPORT_X_BUTTON_ALLOWED_ACTIONS.key?(action)

    send(REPORT_X_BUTTON_ALLOWED_ACTIONS[action])
  end

  def upload
    @sb[:flash_msg] = []
    if params.fetch_path(:upload, :file) && File.size(params[:upload][:file].tempfile) == 0
      redirect_to :action      => 'explorer',
                  :flash_msg   => _("Import file cannot be empty"),
                  :flash_error => true
      return
    end
    if params[:upload] && params[:upload][:file] && params[:upload][:file].respond_to?(:read)
      @sb[:overwrite] = !params[:overwrite].nil?
      begin
        reps, mri = MiqReport.import(params[:upload][:file], :save => true, :overwrite => @sb[:overwrite], :userid => session[:userid])
      rescue StandardError => bang
        add_flash(_("Error during '%s': ") % "upload" << bang.message, :error)
        @sb[:flash_msg] = @flash_array
        redirect_to :action => 'explorer'
      else
        self.x_active_tree = :export_tree
        self.x_node ||= "root"
        @sb[:flash_msg] = mri
        redirect_to :action => 'explorer'
      end
    else
      redirect_to :action        => 'explorer',
                  :flash_msg     => _("Use the Browse button to locate an Import file"),
                  :flash_warning => true
    end
  end

  # New tab was pressed
  def change_tab
    case params[:tab].split("_")[0]
    when "new"
      redirect_to(:action => "miq_report_new", :tab => params[:tab])
    when "edit"
      redirect_to(:action => "miq_report_edit", :tab => params[:tab])
    when "schedules"
      redirect_to(:action => params[:tab])
    when "saved_reports"
      redirect_to(:action => params[:tab])
    when "menueditor"
      # redirect_to(:controller=>"configuration", :action=>"change_tab", :tab=>6)
      redirect_to(:action => "menu_edit")
    else
      redirect_to(:action => params[:tab], :id => params[:id])
    end
  end

  def explorer
    @explorer = true
    @lastaction      = "explorer"
    @ght_type        = nil
    @report          = nil
    @edit            = nil
    @timeline        = true
    @timezone_abbr   = get_timezone_abbr
    @timezone_offset = get_timezone_offset
    @sb[:select_node] = false
    @sb[:open_tree_nodes] ||= []
    @trees = []
    @accords = []
    @lists = []

    # if AJAX request, replace right cell, and return
    if request.xml_http_request?
      switch_ght if params[:type]
      replace_right_cell
      return
    end

    if role_allows(:feature => "miq_report_saved_reports")
      build_savedreports_tree
      @trees.push("savedreports_tree")
      @accords.push(:name => "savedreports", :title => "Saved Reports", :container => "savedreports_accord")
      @lists.push("savedreports_list")
      self.x_active_tree ||= 'savedreports_tree'
      self.x_active_accord ||= 'savedreports'
    end

    if role_allows(:feature => "miq_report_reports", :any => true)
      build_report_listnav
      @trees.push("reports_tree")
      @accords.push(:name => "reports", :title => "Reports", :container => "reports_accord")
      @lists.push("report_list")
      self.x_active_tree ||= 'reports_tree'
      self.x_active_accord ||= 'reports'
    end

    if role_allows(:feature => "miq_report_schedules", :any => true)
      build_schedules_tree
      @trees.push("schedules_tree")
      @accords.push(:name => "schedules", :title => "Schedules", :container => "schedules_accord")
      @lists.push("schedule_list")
      self.x_active_tree ||= 'schedules_tree'
      self.x_active_accord ||= 'schedules'
    end

    if role_allows(:feature => "miq_report_dashboard_editor")
      build_db_tree
      @trees.push("db_tree")
      @accords.push(:name => "db", :title => "Dashboards", :container => "db_accord")
      @lists.push("db_list")
      self.x_active_tree ||= 'db_tree'
      self.x_active_accord ||= 'db'
    end

    if role_allows(:feature => "miq_report_widget_editor")
      build_widgets_tree
      @trees.push("widgets_tree")
      @accords.push(:name => "widgets", :title => "Dashboard Widgets", :container => "widgets_accord")
      @lists.push("widget_list")
      self.x_active_tree ||= 'widgets_tree'
      self.x_active_accord ||= 'widgets'
    end

    if role_allows(:feature => "miq_report_menu_editor")
      build_roles_tree(:roles, :roles_tree)
      @trees.push("roles_tree")
      @accords.push(:name => "roles", :title => "Edit Report Menus", :container => "roles_accord")
      @lists.push("role_list")
      self.x_active_tree ||= 'roles_tree'
      self.x_active_accord ||= 'roles'
      #      x_node_set("root", :roles_tree)
    end

    if role_allows(:feature => "miq_report_export")
      build_export_tree
      @trees.push("export_tree")
      @accords.push(:name => "export", :title => "Import/Export", :container => "export_accord")
      @lists.push("export")
      self.x_active_tree ||= "export_tree"
      self.x_active_accord ||= "export"
    end

    @widget_nodes ||= []
    @sb[:node_clicked] = false
    x_node_set("root", :roles_tree) if params[:load_edit_err]
    @flash_array = @sb[:flash_msg] unless @sb[:flash_msg].blank?
    get_node_info
    @right_cell_text ||= _("All %s") % ui_lookup(:models => "MiqReport")
    @sb[:rep_tree_build_time] = Time.now.utc
    @sb[:active_tab] = "report_info"
    @right_cell_text.gsub!(/'/, "&apos;")      # Need to escape single quote in title to load in right cell
    @x_edit_buttons_locals = set_form_locals if @in_a_form
    # show form buttons after upload is pressed
    @collapse_c_cell = !@in_a_form && !@pages && !saved_report_paging?
    render :layout => "application"
  end

  def accordion_select
    @sb[:flash_msg]   = []
    @schedules = nil
    @edit             = nil
    if params[:id]
      self.x_active_accord = params[:id].sub(/_accord$/, '')
      self.x_active_tree   = "#{self.x_active_accord}_tree"
      x_node_set("root", :roles_tree) unless @changed   # reset menu editor to show All Roles if nothing has been changed

      trees_to_replace = []
      trees_to_replace << :widgets if params[:id] == "widgets"
      trees_to_replace << :reports if params[:id] == "reports"

      replace_right_cell(:replace_trees => trees_to_replace)
    else
      render :nothing => true
    end
  end

  # Item clicked on in the explorer right cell
  def x_show
    @explorer = true
    tree_select
  end

  def tree_select
    @edit = nil
    @sb[:select_node] = false
    # set these when a link on one of the summary screen was pressed
    self.x_active_accord = params[:accord]           if params[:accord]
    self.x_active_tree   = "#{params[:accord]}_tree" if params[:accord]
    self.x_active_tree   = params[:tree]             if params[:tree]
    self.x_node = params[:id]
    @sb[:active_tab] = "report_info" if x_active_tree == :reports_tree && params[:action] != "reload"
    if params[:action] == "reload" && @sb[:active_tab] == "saved_reports"
      replace_right_cell(:replace_trees => [:reports, :savedreports])
    else
      replace_right_cell
    end
  end

  # called to refresh report and from all saved report list view
  def get_report
    self.x_node = params[:id]
    replace_right_cell
  end

  def export_widgets
    if params[:widgets]
      widgets = MiqWidget.where(:id => params[:widgets])
      widget_yaml = MiqWidget.export_to_yaml(widgets, MiqWidget)
      timestamp = format_timezone(Time.current, Time.zone, "export_filename")
      send_data(widget_yaml, :filename => "widget_export_#{timestamp}.yml")
    else
      add_flash(_("At least %{num} %{model} must be selected for %{action}") % {:num => 1, :model => "item", :action => "export"}, :error)
      @sb[:flash_msg] = @flash_array
      redirect_to :action => :explorer
    end
  end

  def upload_widget_import_file
    redirect_options = {:action => :review_import}

    upload_file = params.fetch_path(:upload, :file)

    if upload_file.nil?
      add_flash("Use the browse button to locate an import file", :warning)
    else
      begin
        import_file_upload_id = widget_import_service.store_for_import(upload_file.read)
        add_flash(_("Import file was uploaded successfully"), :info)
        redirect_options[:import_file_upload_id] = import_file_upload_id
      rescue WidgetImportValidator::NonYamlError
        add_flash(_("Error: the file uploaded is not of the supported format"), :error)
      rescue WidgetImportValidator::InvalidWidgetYamlError
        add_flash(_("Error: the file uploaded contains no widgets"), :error)
      end
    end

    redirect_options[:message] = @flash_array.first.to_json

    redirect_to redirect_options
  end

  def import_widgets
    import_file_upload = ImportFileUpload.where(:id => params[:import_file_upload_id]).first

    if import_file_upload
      $log.info("[#{session[:userid]}] initiated import")
      widget_import_service.import_widgets(import_file_upload, params[:widgets_to_import])
      add_flash(_("Widgets imported successfully"), :info)
    else
      add_flash(_("Error: Widget import file upload expired"), :error)
    end

    respond_to do |format|
      format.js { render :json => @flash_array.to_json, :status => 200 }
    end
  end

  def widget_json
    import_file_upload_json = ImportFileUpload.find(params[:import_file_upload_id]).widget_json

    respond_to do |format|
      format.json { render :json => import_file_upload_json }
    end
  end

  def review_import
    @import_file_upload_id = params[:import_file_upload_id]
    @message = params[:message]
  end

  def cancel_import
    widget_import_service.cancel_import(params[:import_file_upload_id])
    add_flash(_("Widget import cancelled"), :info)

    respond_to do |format|
      format.js { render :json => @flash_array.to_json, :status => 200 }
    end
  end

  private ###########################

  def report_selection_menus
    @folders = []
    @menu.each do |r|
      @folders.push(r[0])
      next unless @edit[:new][:filter].present?
      @sub_folders ||= []
      next unless r[0] == @edit[:new][:filter]
      r[1].each do |subfolder, reps|
        subfolder.to_miq_a.each do |s|
          @sub_folders.push(s)
        end
        @reps ||= [] if @edit[:new][:subfilter]
        get_subfilter_reports(reps) if @edit[:new][:subfilter].present? && subfolder == @edit[:new][:subfilter]
      end
    end
  end

  def get_subfilter_reports(reps)
    reports = MiqReport.where(:name => reps)
    reports.each do |report|
      next if x_active_tree == :widgets_tree && report.db == "VimPerformanceTrend"
      temp_arr = []
      temp_arr.push(report.name)
      temp_arr.push(report.id)
      @reps.push(temp_arr) unless @reps.include?(temp_arr)
    end
  end

  # Graph/Hybrid/Tabular toggle button was hit (ajax version)
  def switch_ght
    rr      = MiqReportResult.find(@sb[:pages][:rr_id])
    @html   = report_build_html_table(rr.report_results,
                                      rr.html_rows(:page     => @sb[:pages][:current],
                                                   :per_page => @sb[:pages][:perpage]).join)
    @report = rr.report_results                 # Grab the blobbed report, including table
    @zgraph = nil
    @html   = nil
    if ["tabular", "hybrid"].include?(params[:type])
      @html = report_build_html_table(@report,
                                      rr.html_rows(:page     => @sb[:pages][:current],
                                                   :per_page => @sb[:pages][:perpage]).join)
    end
    if ["graph", "hybrid"].include?(params[:type])
      @zgraph = true      # Show the zgraph in the report
    end
    @ght_type = params[:type]
    @title = @report.title
  end

  def rebuild_trees
    rep = MiqReportResult.where(set_saved_reports_condition).limit(1).order('created_on desc').pluck("created_on").first
    return false unless rep
    build_trees = rep > @sb[:rep_tree_build_time]
    # save last tree build time to decide if tree needs to be refreshed automatically
    @sb[:rep_tree_build_time] = Time.now.utc if build_trees
    build_trees
  end

  # Build the main import/export tree
  def build_export_tree(type = :export, name = :export_tree)
    x_tree_init(name, type, "Import / Export", :open_all => true, :add_root => false)
    tree_nodes = x_build_dynatree(x_tree(name))

    instance_variable_set :"@#{name}", tree_nodes.to_json          # JSON object for tree loading
    x_node_set(tree_nodes.first[:key], name) unless x_node(name)  # Set active node to root if not set
  end

  def determine_root_node_info
    case x_active_tree
    when :db_tree
      db_get_node_info
    when :export_tree
      @export = true
      get_export_reports
      @right_cell_text ||= "Import / Export"
      @help_topic        = request.parameters["controller"] + "-import_export"
    when :roles_tree
      menu_get_all
      @changed = session[:changed] = false
      @help_topic = request.parameters["controller"] + "-menus_editor"
    when :reports_tree
      @right_cell_text ||= "All Reports"
    when :savedreports_tree
      get_all_saved_reports
    when :schedules_tree
      @schedule = nil
      schedule_get_all
      @help_topic = request.parameters["controller"] + "-schedules_list"
    when :widgets_tree
      widget_get_node_info
    end
  end

  def determine_g_node_info(nodeid)
    if x_active_tree == :roles_tree
      @sb[:menu_buttons] = true
      get_menu(nodeid) unless nodeid.blank?
    else
      db_get_node_info
    end
  end

  def determine_xx_node_info
    if x_active_tree == :savedreports_tree
      saved_reports_get_node_info
    elsif x_active_tree == :db_tree
      db_get_node_info
    elsif x_active_tree == :reports_tree
      reports_get_node_info
    elsif x_active_tree == :widgets_tree
      widget_get_node_info
    elsif x_active_tree == :export_tree
      export_get_node_info
    end
  end

  def determine_rr_node_info
    nodes = x_node.split('-')
    show_saved_report
    @record = MiqReportResult.find_by_id(from_cid(nodes.last))
    @right_cell_text = _("%{model} \"%{name}\"") % {
      :name  => "#{@record.name} - #{format_timezone(@record.created_on, Time.zone, "gt")}",
      :model => "Saved Report"
    }
    @right_cell_div  = "savedreports_list"
  end

  def export_get_node_info
    @right_cell_text = "Import / Export"
    if x_node.split('-').last == "exportcustomreports"
      get_export_reports
      @right_cell_div = "export_custom_reports"
    else
      @in_a_form = true
      @widget_exports = MiqWidget.all.reject(&:read_only).collect { |widget| [widget.title, widget.id] }
      @right_cell_div = "export_widgets"
    end
  end

  def saved_reports_get_node_info
    nodes = x_node.split('-')
    get_all_reps(nodes[1])
    miq_report = MiqReport.find(@sb[:miq_report_id])
    @sb[:sel_saved_rep_id] = nodes.last
    @right_cell_div        = "savedreports_list"
    @right_cell_text = _("%{model} \"%{name}\"") % {:name  => miq_report.name, :model => "Saved Reports"}
  end

  def reports_get_node_info
    nodes = x_node.split('-')

    if nodes.length == 2
      @right_cell_text ||= _("%{typ} %{model}") % {:typ   => @sb[:rpt_menu][nodes[1].to_i][0], :model => ui_lookup(:models => "MiqReport")}

    elsif nodes.length == 4 && @sb[:rpt_menu][nodes[1].to_i].present?
      @sb[:rep_details] = {}

      @sb[:rpt_menu][nodes[1].to_i][1][nodes[3].to_i][1].each_with_index do |rep, _|
        r = MiqReport.find_by_name(rep)
        if r
          details                    = {}
          details["display_filters"] = r.display_filter ? true : false
          details["filters"]         = r.conditions ? true : false
          details["charts"]          = r.graph ? true : false
          details["sortby"]          = r.sortby ? true : false
          details["id"]              = r.id
          details["user"]            = r.user ? r.user.userid : ""
          details["group"]           = r.miq_group ? r.miq_group.description : ""
          @sb[:rep_details][r.name]  = details
        end
      end

      @right_cell_text ||= _("%{typ} %{model}") % {:typ   => @sb[:rpt_menu][nodes[1].to_i][1][nodes[3].to_i][0], :model => ui_lookup(:models => "MiqReport")}

    elsif nodes.length == 4 && @sb[:rpt_menu][nodes[1].to_i].nil?
      x_node_set("root", x_active_tree)

    elsif nodes.length == 5
      @sb[:selected_rep_id] = from_cid(nodes[4])
      if role_allows(:feature => "miq_report_widget_editor")
        # all widgets for this report
        get_all_widgets("report", from_cid(nodes[4]))
      end
      get_all_reps(nodes[4])

    elsif nodes.length == 6
      @sb[:last_saved_id] = x_node
      @sb[:miq_report_id] = nil
      show_saved
    end

    @right_cell_div ||= "report_list"
    @right_cell_text ||= _("All %s") % ui_lookup(:models => "MiqReport")
  end

  # Get all info for the node about to be displayed
  def get_node_info
    treenodeid = valid_active_node(x_node)
    if [:db_tree, :reports_tree, :saved_tree, :savedreports_tree, :widgets_tree].include?(x_active_tree)
      @nodetype         = treenodeid.split("-")[0]
      self.x_active_tree = :savedreports_tree if @nodetype == "saved"
      nodeid            = treenodeid.split("-")[1] if treenodeid.split("-")[1]
    else
      @nodetype, nodeid = treenodeid.split("-")
    end
    @sb[:menu_buttons] = false

    case @nodetype
    when "root"
      determine_root_node_info
    when "g"
      determine_g_node_info(nodeid)
    when "xx"
      determine_xx_node_info
    when "rr"
      determine_rr_node_info
    when "msc"
      get_schedule(nodeid) unless nodeid.blank?
      @sb[:selected_sched_id] = nodeid unless nodeid.blank?
    end

    x_history_add_item(:id => treenodeid, :text => @right_cell_text)
  end

  def get_export_reports
    @changed = session[:changed] = true
    @in_a_form = true
    @export_reports = {}
    user = current_user
    MiqReport.all.each do |rep|
      if rep.rpt_type == "Custom" && (user.admin_user? || (rep.miq_group && rep.miq_group.id == user.current_group.id))
        @export_reports[rep.name] = rep.id
      end
    end
  end

  def set_form_locals
    locals = {}
    if x_active_tree == :export_tree
      if x_node == "xx-exportwidgets"
        action_url = nil
        record_id = nil
      else
        action_url = "download_report"
        locals[:no_reset] = true
        locals[:no_cancel] = true
        locals[:multi_record] = true
        locals[:export_button] = true
      end
    elsif x_active_tree == :schedules_tree || params[:pressed] == "miq_report_schedule_add"
      action_url = "schedule_edit"
      record_id = @edit[:sched_id] ? @edit[:sched_id] : nil
    elsif x_active_tree == :widgets_tree
      action_url = "widget_edit"
      record_id = @edit[:widget_id] ? @edit[:widget_id] : nil
    elsif x_active_tree == :db_tree
      if @edit[:new][:dashboard_order]
        action_url = "db_seq_edit"
        locals[:multi_record] = true
      else
        action_url = "db_edit"
        record_id = @edit[:db_id] ? @edit[:db_id] : nil
      end
    elsif x_active_tree == :reports_tree
      action_url = "miq_report_edit"
      record_id = @edit[:rpt_id] ? @edit[:rpt_id] : nil
    elsif x_active_tree == :roles_tree
      action_url = "menu_update"
      locals[:default_button] = true
      record_id = @edit[:user_group]
    end
    locals[:action_url] = action_url
    locals[:record_id] = record_id
    locals
  end

  def set_partial_name
    case x_active_tree
    when :db_tree
      return "db_list"
    when :export_tree
      return "export"
    when :reports_tree
      return params[:pressed] == "miq_report_schedule_add" ? "schedule_list" : "report_list"
    when :roles_tree
      return "role_list"
    when :savedreports_tree
      return "savedreports_list"
    when :schedules_tree
      return "schedule_list"
    when :widgets_tree
      return "widget_list"
    else
      return "role_list"
    end
  end

  # Check for parent nodes missing from vandt tree and return them if any
  def open_parent_nodes
    existing_node = nil                     # Init var
    nodes = params[:id].split('_')
    nodes.pop
    parents = []
    nodes.each do |node|
      parents.push(:id => node.split('xx-').last)
    end

    # Go up thru the parents and find the highest level unopened, mark all as opened along the way
    unless parents.empty? || # Skip if no parents or parent already open
           x_tree[:open_nodes].include?(x_build_node_id(parents.last))
      parents.reverse_each do |p|
        p_node = x_build_node_id(p)
        # some of the folder nodes are not autoloaded
        # that's why they already exist in open_nodes
        x_tree[:open_nodes].push(p_node) unless x_tree[:open_nodes].include?(p_node)
        existing_node = p_node
      end
    end

    add_nodes = {:key      => existing_node,
                 :children => tree_add_child_nodes(existing_node)} if existing_node
    self.x_node = params[:id]
    add_nodes
  end

  def replace_right_cell(options = {})  # :replace_trees key can be an array of tree symbols to be replaced
    @explorer = true

    replace_trees = options[:replace_trees] || []
    get_node_info unless @in_a_form
    replace_trees = @replace_trees if @replace_trees  # get_node_info might set this
    # nodetype is special for menu editor, so set it to :menu_edit_action if passed in, else use x_node prefix
    nodetype = options[:menu_edit_action] ? options[:menu_edit_action] : x_node.split('-').first

    @sb[:active_tab] = params[:tab_id] ? params[:tab_id] : "report_info" if x_active_tree == :reports_tree &&
                                                                            params[:action] != "reload" && !["miq_report_run", "saved_report_delete"].include?(params[:pressed]) # do not reset if reload saved reports buttons is pressed

    rebuild = @in_a_form ? false : rebuild_trees
    build_report_listnav    if replace_trees.include?(:reports) || rebuild
    build_schedules_tree    if replace_trees.include?(:schedules)
    build_savedreports_tree if replace_trees.include?(:savedreports) || rebuild
    build_db_tree           if replace_trees.include?(:db) || rebuild
    build_widgets_tree      if replace_trees.include?(:widgets) || rebuild

    presenter = ExplorerPresenter.new(
      :active_tree => x_active_tree,
    )
    # Clicked on right cell record, open the tree enough to show the node, if not already showing
    # Open the parent nodes of selected record, if not open
    presenter[:add_nodes] = open_parent_nodes if params[:action] == 'x_show'
    r = proc { |opts| render_to_string(opts) }
    presenter[:open_accord] = params[:accord] if params[:accord] # Open new accordion

    locals = set_form_locals if @in_a_form
    partial = set_partial_name
    unless @in_a_form
      c_buttons, c_xml = build_toolbar_buttons_and_xml(center_toolbar_filename)
      h_buttons, h_xml = build_toolbar_buttons_and_xml("x_history_tb")
      v_buttons, v_xml = build_toolbar_buttons_and_xml("report_view_tb") if @report && [:reports_tree, :savedreports_tree].include?(x_active_tree)
    end

    # With dynatree, simply replace the tree partials to reload the trees
    replace_trees.each do |t|
      case t
      when :reports
        presenter[:replace_partials][:reports_tree_div] = r[:partial => "reports_tree"]
      when :schedules
        presenter[:replace_partials][:schedules_tree_div] = r[:partial => "schedules_tree"]
      when :savedreports
        presenter[:replace_partials][:savedreports_tree_div] = r[:partial => "savedreports_tree"]
      when :db
        presenter[:replace_partials][:db_tree_div] = r[:partial => "db_tree"]
      when :widgets
        presenter[:replace_partials][:widgets_tree_div] = r[:partial => "widgets_tree"]
      end
    end

    presenter[:osf_node] = x_node  # Open, select, and focus on this node

    session[:changed] = (@edit[:new] != @edit[:current]) if @edit && @edit[:current] # to get save/reset buttons to highlight when something is changed

    if nodetype == 'root' || (nodetype != 'root' && x_active_tree != :roles_tree)
      presenter[:update_partials][:main_div] = r[:partial => partial]
      case x_active_tree
      when :db_tree
        presenter[:open_accord] = 'db'   # have to make db accordion active incase coming from report list
        if @in_a_form
          if @edit[:new][:dashboard_order]
            @right_cell_text = _("Editing %{model} sequence for \"%{name}\"") % {:name => @sb[:group_desc], :model => "Dashboard"}
          else
            @right_cell_text = @db.id ?
                _("Editing %{model} \"%{name}\"") % {:name => @db.name, :model => "Dashboard"} : _("Adding a new %s") % "dashboard"
          end
          # URL to be used in miqDropComplete method
          presenter[:miq_widget_dd_url] = "report/db_widget_dd_done"
          presenter[:init_dashboard] = true
        end
      when :export_tree
        @right_cell_text = _("Import / Export")
      when :reports_tree
        if params[:pressed] == "miq_report_schedule_add"
          presenter[:open_accord] = 'schedules'
          if @in_a_form
            presenter[:build_calendar] = true
            @right_cell_text = @schedule.id ?
                _("Editing %{model} \"%{name}\"") % {:name => @schedule.name, :model => ui_lookup(:model => "MiqSchedule")} :
                _("Adding a new %s") % ui_lookup(:model => "MiqSchedule")
          end
        else
          if @in_a_form
            @right_cell_text = @rpt.id ?
                _("Editing %{model} \"%{name}\"") % {:name => @rpt.name, :model => ui_lookup(:model => "MiqReport")} : _("Adding a new %s") % ui_lookup(:model => "MiqReport")
          end
        end
      when :schedules_tree
        presenter[:open_accord] = 'schedules'
        if @in_a_form
          presenter[:build_calendar] = true
          @right_cell_text = @schedule.id ?
              _("Editing %{model} \"%{name}\"") % {:name => @schedule.name, :model => ui_lookup(:model => 'MiqSchedule')} :
              _("Adding a new %s") % ui_lookup(:model => 'MiqSchedule')
        end
      when :widgets_tree
        presenter[:open_accord] = 'widgets'
        if @in_a_form
          presenter[:build_calendar] = {
            :date_from => Time.now.in_time_zone(@edit[:tz]).to_i * 1000,
            :date_to   => nil,
          }
          # URL to be used in miqDropComplete method
          if @sb[:wtype] == 'm'
            presenter[:miq_widget_dd_url] = 'report/widget_shortcut_dd_done'
            presenter[:init_dashboard] = true
          end
          @right_cell_text = @widget.id ?
              _("Editing %{model} \"%{name}\"") % {:name => @widget.name, :model => ui_lookup(:model => 'MiqWidget')} :
              _("Adding a new %s") % ui_lookup(:model => 'MiqWidget')
        end
      end
    elsif nodetype == "g"
      # group in menu editor is selected
      if @sb[:node_clicked]
        # folder selected to edit in menu tree
        val = session[:node_selected].split('__')[0]
        if val == "b"
          skin_class        = "menueditor"
          fieldset_title    = "Manage Accordions"
          img_title_top     = "Move selected Accordion to top"
          img_title_up      = "Move selected Accordion up"
          img_title_down    = "Move selected Accordion down"
          img_title_add     = "Add folder to selected Accordion"
          img_title_delete  = "Delete selected Accordion and its contents"
          img_title_bottom  = "Move selected Accordion to bottom"
          img_title_commit  = "Commit Accordion management changes"
          img_title_discard = "Discard Accordion management changes"
        else
          skin_class        = "menueditor2"
          fieldset_title    = "Manage Folders"
          img_title_top     = "Move selected folder to top"
          img_title_up      = "Move selected folder up"
          img_title_down    = "Move selected folder down"
          img_title_add     = "Add subfolder to selected folder"
          img_title_delete  = "Delete selected folder and its contents"
          img_title_bottom  = "Move selected folder to bottom"
          img_title_commit  = "Commit folder management changes"
          img_title_discard = "Discard folder management changes"
        end
        presenter[:update_partials][:main_div] = r[:partial => partial]
        presenter[:element_updates][:menu1_legend] = {:legend => fieldset_title}
        presenter[:set_visible_elements][:menu_div1]  = true
        presenter[:set_visible_elements][:menu_div2]  = false
        presenter[:set_visible_elements][:treeStatus] = true
        presenter[:set_visible_elements][:flash_msg_div_menu_list] = "hide"
        # js_options[:set_folder_grid_contents] = true #?!?! FIXME: remove
        presenter[:grid_name] = 'folder_list_grid' #
        presenter[:element_updates][:folder_top]      = {:title => img_title_top}
        presenter[:element_updates][:folder_up]       = {:title => img_title_up}
        presenter[:element_updates][:folder_down]     = {:title => img_title_down}
        presenter[:element_updates][:folder_add]      = {:title => img_title_add}
        presenter[:element_updates][:folder_delete]   = {:title => img_title_delete}
        presenter[:element_updates][:folder_bottom]   = {:title => img_title_bottom}
        presenter[:element_updates][:folder_commit]   = {:title => img_title_commit}
        presenter[:element_updates][:folder_discard]  = {:title => img_title_discard}
      else
        presenter[:update_partials][:main_div] = r[:partial => partial]
        presenter[:clear_tree_cookies] = "edit_treeOpenStatex"
        unless @sb[:role_list_flag]
          # on first time load we dont need to do replace in order to load dhtmlxgrid
          @sb[:role_list_flag] = true
          presenter[:set_visible_elements][:treeStatus] = true
        end
        presenter[:set_visible_elements][:menu_div1] = false
        presenter[:set_visible_elements][:menu_div2] = false
        presenter[:set_visible_elements][:menu_div3] = true
      end
    elsif nodetype == "menu_default" || nodetype == "menu_reset"
      presenter[:update_partials][:main_div]   = r[:partial => partial]
      presenter[:replace_partials][:menu_div1] = r[:partial => "menu_form1"]
      presenter[:set_visible_elements][:menu_div1]  = false
      presenter[:set_visible_elements][:menu_div2]  = false
      presenter[:set_visible_elements][:menu_div3]  = true
      presenter[:set_visible_elements][:treeStatus] = false
      # set changed to true if menu has been set to default
      session[:changed] = @sb[:menu_default] ? true : (@edit[:new] != @edit[:current])
    elsif nodetype == "menu_edit_reports"
      presenter[:replace_partials][:flash_msg_div_menu_list] = r[:partial => "layouts/flash_msg", :locals => {:div_num => "_menu_list"}] if @flash_array
      presenter[:set_visible_elements][:menu_div1]  = true
      presenter[:set_visible_elements][:treeStatus] = true
      presenter[:replace_partials][:menu_div2] = r[:partial => "menu_form2"]
      presenter[:set_visible_elements][:menu_div1] = false
      presenter[:set_visible_elements][:menu_div3] = false
      presenter[:set_visible_elements][:menu_div2] = true
    elsif nodetype == "menu_commit_reports"
      presenter[:replace_partials][:flash_msg_div_menu_list] = r[:partial => "layouts/flash_msg", :locals => {:div_num => "_menu_list"}] if @flash_array
      if @refresh_div
        presenter[:set_visible_elements][:flash_msg_div_menu_list] = false
        presenter[:replace_partials]["#{@refresh_div}".to_sym] = r[:partial => @refresh_partial, :locals => {:action_url => "menu_update"}]
        presenter[:set_visible_elements][:menu_div1] = false
        if params[:pressed] == "commit"
          presenter[:set_visible_elements][:menu_div3] = true
          presenter[:set_visible_elements][:menu_div2] = false
        else
          presenter[:set_visible_elements][:menu_div3] = false
          presenter[:set_visible_elements][:menu_div2] = true
        end
      elsif !@flash_array
        presenter[:replace_partials][:menu_roles_div] = r[:partial => "role_list"]
        if params[:pressed] == "commit"
          presenter[:set_visible_elements][:flash_msg_div_menu_list] = false
          presenter[:set_visible_elements][:menu_div3] = true
          presenter[:set_visible_elements][:menu_div1] = false
          presenter[:set_visible_elements][:menu_div2] = false
        else
          presenter[:set_visible_elements][:menu_div1] = false
          presenter[:set_visible_elements][:menu_div3] = false
          presenter[:set_visible_elements][:menu_div2] = true
        end
        presenter[:set_visible_elements][:treeStatus] = false
      end
    elsif nodetype == 'menu_commit_folders'
      # Hide flash_msg if it's being shown from New folder add event
      presenter[:set_visible_elements][:flash_msg_div_menu_list] = false
      if @sb[:tree_err]
        presenter[:set_visible_elements][:menu_div1] = true
        presenter[:set_visible_elements][:menu_div2] = false
        presenter[:set_visible_elements][:menu_div3] = false
      else
        presenter[:replace_partials][:menu_roles_div] = r[:partial => "role_list"]
        presenter[:set_visible_elements][:menu_div1]  = false
        presenter[:set_visible_elements][:menu_div2]  = false
        presenter[:set_visible_elements][:menu_div3]  = true
        presenter[:set_visible_elements][:treeStatus] = false
      end
      @sb[:tree_err] = false
    elsif nodetype == 'menu_discard_folders' || nodetype == 'menu_discard_reports'
      presenter[:replace_partials][:flash_msg_div_menu_list] = r[:partial => 'layouts/flash_msg', :locals => {:div_num => '_menu_list'}]
      presenter[:replace_partials][:menu_div1]               = r[:partial => 'menu_form1', :locals => {:action_url => 'menu_update'}]
      presenter[:set_visible_elements][:menu_div1]  = false
      presenter[:set_visible_elements][:menu_div2]  = false
      presenter[:set_visible_elements][:menu_div3]  = true
      presenter[:set_visible_elements][:treeStatus] = false
    end

    if x_active_tree == :roles_tree && x_node != "root"
      @right_cell_text = _("Editing %{model} \"%{name}\"") % {:name => session[:role_choice], :model => ui_lookup(:model => "MiqGroup")}
    end
    presenter[:right_cell_text] = @right_cell_text

    # Handle bottom cell
    if (@in_a_form || @pages) || (@sb[:pages] && @html)
      if @pages
        @ajax_paging_buttons = true # FIXME: this should not be done this way
        presenter[:update_partials][:paging_div] = r[:partial => 'layouts/x_pagingcontrols']
        presenter[:set_visible_elements][:form_buttons_div] = false
        presenter[:set_visible_elements][:rpb_div_1]        = false
        presenter[:set_visible_elements][:pc_div_1]         = true
      elsif @in_a_form
        presenter[:update_partials][:form_buttons_div] = r[:partial => 'layouts/x_edit_buttons', :locals => locals]
        presenter[:set_visible_elements][:pc_div_1]         = false
        presenter[:set_visible_elements][:rpb_div_1]        = false
        presenter[:set_visible_elements][:form_buttons_div] = true
      elsif @sb[:pages]
        presenter[:update_partials][:paging_div] = r[:partial => 'layouts/saved_report_paging_bar', :locals => @sb[:pages]]
        presenter[:set_visible_elements][:form_buttons_div] = false
        presenter[:set_visible_elements][:rpb_div_1]        = true
        presenter[:set_visible_elements][:pc_div_1]         = false
      end
      presenter[:show_hide_layout][:paginator] = 'show'
    else
      presenter[:show_hide_layout][:paginator] = 'hide'
    end
    presenter[:show_hide_layout][:paginator] = 'hide' if @sb[:active_tab] == 'report_info' && x_node.split('-').length == 5 && !@in_a_form
    presenter[:show_hide_layout][:toolbar] = @in_a_form ? 'hide' : 'show'

    # Rebuild the toolbars
    presenter[:set_visible_elements][:history_buttons_div] = h_buttons && h_xml
    presenter[:set_visible_elements][:center_buttons_div]  = c_buttons && c_xml
    presenter[:set_visible_elements][:view_buttons_div]    = v_buttons && v_xml

    presenter[:reload_toolbars][:history] = {:buttons => h_buttons, :xml => h_xml} if h_buttons && h_xml
    presenter[:reload_toolbars][:center]  = {:buttons => c_buttons, :xml => c_xml} if c_buttons && c_xml
    presenter[:reload_toolbars][:view]    = {:buttons => v_buttons, :xml => v_xml} if v_buttons && v_xml

    if @record && !@in_a_form
      presenter[:record_id] = @record.id
    else
      presenter[:record_id] = @edit && @edit[:rec_id] && @in_a_form ? @edit[:rec_id] : nil
    end

    # Lock current tree if in edit or assign, else unlock all trees
    if @edit && @edit[:current]
      presenter[:lock_unlock_trees][x_active_tree] = true
      # lock schedules tree when jumping from reports to add a schedule for a report
      presenter[:lock_unlock_trees][:schedules_tree] = true if params[:pressed] == 'miq_report_schedules'
    else
      presenter[:lock_unlock_trees][x_active_tree] = false
      [:db_tree, :reports_tree, :savedreports_tree, :schedules_tree, :widgets_tree, :roles_tree].each do |tree|
        presenter[:lock_unlock_trees][tree] = false
      end
    end

    # Render the JS responses to update the explorer screen
    render :js => presenter.to_html
  end

  def get_session_data
    @layout           = request.parameters[:action].starts_with?('usage') ? 'usage' : 'report'
    @lastaction       = session[:report_lastaction]
    @report_tab       = session[:report_tab]
    @report_result_id = session[:report_result_id]
    @menu             = session[:report_menu]
    @folders          = session[:report_folders]
    @ght_type         = session[:ght_type] || "tabular"
    @report_groups    = session[:report_groups]
    @edit             = session[:edit] unless session[:edit].nil?
    @catinfo          = session[:vm_catinfo]
  end

  def set_session_data
    session[:report_lastaction] = @lastaction
    session[:report_tab]        = @report_tab
    session[:panels]            = @panels
    session[:ght_type]          = @ght_type
    session[:report_groups]     = @report_groups
    session[:vm_catinfo]        = @catinfo
    session[:vm_cats]           = @cats
    session[:edit]              = @edit unless @edit.nil?
    session[:report_result_id]  = @report_result_id
    session[:report_menu]       = @menu
    session[:report_folders]    = @folders
  end

  def widget_import_service
    @widget_import_service ||= WidgetImportService.new
  end
end
