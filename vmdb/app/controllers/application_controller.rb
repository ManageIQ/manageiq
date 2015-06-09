require 'open-uri'
require 'simple-rss'

# Need to make sure models are autoloaded
MiqCompare
MiqFilter
MiqExpression
MiqSearch

class ApplicationController < ActionController::Base

  if Vmdb::Application.config.action_controller.allow_forgery_protection
    protect_from_forgery :secret => MiqDatabase.first.csrf_secret_token, :except => :csp_report
  end

  helper ChartingHelper
  Charting.load_helpers(self)

  include ActionView::Helpers::NumberHelper   # bring in the number helpers for number_to_human_size
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::DateHelper
  include ApplicationHelper
  include JsHelper
  helper JsHelper

  helper CloudResourceQuotaHelper

  include_concern 'Automate'
  include_concern 'CiProcessing'
  include_concern 'Compare'
  include_concern 'Buttons'
  include_concern 'DialogRunner'
  include_concern 'Explorer'
  include_concern 'Filter'
  include_concern 'MiqRequestMethods'
  include_concern 'Performance'
  include_concern 'PolicySupport'
  include_concern 'Tags'
  include_concern 'Timelines'
  include_concern 'TreeSupport'
  include_concern 'SysprepAnswerFile'

  before_filter :get_global_session_data, :except => [:window_sizes, :authenticate]
  before_filter :set_user_time_zone
  before_filter :set_gettext_locale
  after_filter :set_global_session_data, :except => [:window_sizes]

  ensure_security_headers

  # Convert Controller Name to Actual Model
  # Examples:
  #   CimBaseStorageExtentController => CimBaseStorageExtent
  #   OntapFileShareController        => OntapFileShare
  def self.model
    @model ||= model_name.constantize
  end

  def self.model_name
    name[0..-11]
  end

  # Examples:
  #   CimBaseStorageExtentController => cim_base_storage_extent
  #   OntapFileShareController        => ontap_file_share
  def self.table_name
    @table_name ||= self.model.name.underscore
  end

  # Examples:
  #   CimBaseStorageExtentController => cim_bse
  #   OntapFileShareController        => snia_fs
  def self.session_key_prefix
    @session_key_prefix ||= begin
      parts = self.table_name.split('_')
      "#{parts[0]}_#{parts[1..-1].join('_')}"
    end
  end

  # This will rescue any un-handled exceptions
  rescue_from StandardError, :with => :error_handler

  def error_handler(e)
    logger.fatal "Error caught: [#{e.class.name}] #{e.message}\n#{e.backtrace.join("\n")}"

    msg = case e
    when ::ActionController::RoutingError
      "Action not implemented"
    when ::AbstractController::ActionNotFound # Prevent Rails showing all known controller actions
      "Unknown Action"
    else
      e.message
    end

    render_exception(msg)
  end
  hide_action :error_handler

  def render_exception(msg)
    respond_to do |format|
      format.js do
        render :update do |page|    # AJAX, replace the main area with error
          page.replace_html("center_div", :partial => "layouts/exception_contents", :locals => {:message => msg})
          page << "miqSparkle(false);"
          page << javascript_hide_if_exists("adv_searchbox_div")
        end
      end
      format.html do                # HTML, send error screen
        @layout = "exception"
        response.status = 500
        render(:template => "layouts/exception", :locals => { :message => msg })
      end
      format.any { render :nothing => true, :status => 404 }  # Anything else, just send 404
    end
  end
  hide_action :render_exception

  # Put out error msg if user's role is not authorized for an action
  def auth_error
    add_flash(_("The user is not authorized for this task or item."), :error)
    add_flash(_("Press your browser's Back button or click a tab to continue"))
#   render(:text=>"User is not authorized for this task . . . press your browser's Back button to continue")
  end

  def change_tab
    redirect_to(:action=>params[:tab], :id=>params[:id])
  end

  def build_targets_hash(items,typ=true)
    @targets_hash ||= Hash.new
    #if array of objects came in
    if typ
      items.each do |item|
        @targets_hash[item.id.to_i] = item
      end
    else
      # if only array of id's came in look up for a record, following code is not being used right now.
      klass = session[:view].db.constantize
      items.each do |item|
        @targets_hash[item.to_i] = klass.find(item)
      end
    end
  end

  # Control blinds effects on nav panel divs
  def panel_control
    @keep_compare = true
    panel = params[:panel]
    render :update do |page|
      if @panels[panel] == 'down'
        @panels[panel] = 'up'
        page << "$('##{j_str(panel)}').slideUp('medium');"
      else
        @panels[panel] = 'down'
        page << "$('##{j_str(panel)}').slideDown('medium');"
      end
    end
    # FIXME: the @panels end up in the session eventually
    #        so there's a issue with the possibility of inserting arbitrary
    #        keys to the hash
  end

  # Send chart data to the client
  def render_chart
    if params[:report]
      rpt = MiqReport.find_by_name(params[:report])
      rpt.generate_table(:userid => session[:userid])
    else
      rpt = if controller_name == "dashboard" && @sb[:report_result_id] # Check for dashboard results
              MiqReportResult.find(@sb[:report_result_id]).report_results
            elsif session[:rpt_task_id].present?
              MiqTask.find(session[:rpt_task_id]).task_results
            elsif session[:report_result_id]
              MiqReportResult.find(session[:report_result_id]).report_results
            else
              @report
            end
    end

    # Following works around a caching issue that causes timeouts for charts in IE using SSL
    if is_browser_ie?
      response.headers["Cache-Control"] = "cache, must-revalidate"
      response.headers["Pragma"] = "public"
    end

    rpt.to_chart(@settings[:display][:reporttheme], true, MiqReport.graph_options(params[:width], params[:height]))
    render Charting.render_format => rpt.chart
  end

  # Send the current report in text format
  def render_txt
    if session[:rpt_task_id]
      miq_task = MiqTask.find(session[:rpt_task_id])  # Get report task id from the session
      @report = miq_task.task_results
    elsif session[:rpt_task_id].nil? && session[:report_result_id]
      rr = MiqReportResult.find(session[:report_result_id]) # Get report task id from the session
      @report = rr.report_results
      @report.report_run_time = rr.last_run_on
    end
    filename = @report.title + "_" + format_timezone(Time.now,Time.zone,"fname")
    disable_client_cache
    send_data(@report.to_text,
      :filename => "#{filename}.txt" )
  end

  # Send the current report in csv format
  def render_csv
    if session[:rpt_task_id]
      miq_task = MiqTask.find(session[:rpt_task_id])  # Get report task id from the session
      @report = miq_task.task_results
    elsif session[:rpt_task_id].nil? && session[:report_result_id]
      rr = MiqReportResult.find(session[:report_result_id]) # Get report task id from the session
      @report = rr.report_results
    end
    filename = @report.title + "_" + format_timezone(Time.now,Time.zone,"fname")
    disable_client_cache
    send_data(@report.to_csv,
      :filename => "#{filename}.csv" )
  end

  # Send the current report in pdf format
  def render_pdf(report = nil)
    if session[:rpt_task_id]
      miq_task = MiqTask.find(session[:rpt_task_id])
      @report = miq_task.task_results
    elsif session[:report_result_id]
      rr = MiqReportResult.find(session[:report_result_id])
      @report = rr.report_results
    end
    if report || @report
      userid = "#{session[:userid]}|#{request.session_options[:id]}|adhoc"
      rr =  (report || @report).build_create_results(:userid=>userid) # Create rr from the report object
    end

    # Use rr frorm paging, if present
    rr ||= MiqReportResult.find(@sb[:pages][:rr_id]) if @sb[:pages]
    # Use report_result_id in session, if present
    rr ||= MiqReportResult.find(session[:report_result_id]) if session[:report_result_id]

    filename = rr.report.title + "_" + format_timezone(Time.now, Time.zone, "fname")
    disable_client_cache
    send_data(rr.to_pdf, :filename => "#{filename}.pdf", :type => 'application/pdf')
  end

  RENDER_TYPES = {'txt' => 'txt', 'csv' => 'csv', 'pdf' => 'pdf'}

  # Render report in csv/txt/pdf format asynchronously
  def render_report_data
    render_type = RENDER_TYPES[params[:render_type]]
    assert_privileges("render_report_#{render_type}")
    unless params[:task_id] # First time thru, kick off the report generate task
      if render_type
        @sb[:render_type] = render_type.to_sym
        rr = MiqReportResult.find(session[:report_result_id]) # Get report task id from the session
        task_id = rr.async_generate_result(@sb[:render_type], :userid     => session[:userid],
                                                              :session_id => request.session_options[:id])
        initiate_wait_for_task(:task_id => task_id)
      end
      return
    end

    miq_task = MiqTask.find(params[:task_id])
    if miq_task.task_results.blank? || miq_task.status != "Ok"  # Check to see if any results came back or status not Ok
      add_flash(_("Report generation returned: Status [%{status}] Message [%{message}]") % {:status  => miq_task.status, :message => miq_task.message}, :error)
      render :update do |page|
        page << "if (miqDomElementExists('flash_msg_div_report_list')){"
        page.replace("flash_msg_div_report_list", :partial => "layouts/flash_msg",
                                                  :locals  => {:div_num => "_report_list"})
        page << "} else {"
        page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        page << "}"
        page << "miqSparkle(false);"
      end
    else
      @sb[:render_rr_id] = miq_task.miq_report_result.id
      render :update do |page|
        page << "miqSparkle(false);"
        page << "DoNav('#{url_for(:action => "send_report_data")}');"
      end
    end
  end
  alias render_report_txt render_report_data
  alias render_report_csv render_report_data
  alias render_report_pdf render_report_data

  # Send rendered report data
  def send_report_data
    if @sb[:render_rr_id]
      rr = MiqReportResult.find(@sb[:render_rr_id])
      filename = rr.report.title + "_" + format_timezone(Time.now, Time.zone, "fname")
      disable_client_cache
      generated_result = rr.get_generated_result(@sb[:render_type])
      rr.destroy
      send_data(generated_result,
                :filename => "#{filename}.#{@sb[:render_type]}",
                :type     => "application/#{@sb[:render_type]}")
    end
  end

  # Download currently displayed view
  def download_data
    @view = session[:view].dup if session[:view]                     # Copy session view, if it exists
    options = session[:paged_view_search_options].merge(:page => nil, :per_page => nil) # Get all pages
    @view.table, _attrs = @view.paged_view_search(options) # Get the records

    @filename = @view.title + "_" + format_timezone(Time.now, Time.zone, "fname")
    case params[:download_type]
    when "pdf"
      download_pdf(@view)
    when "text"
      download_txt(@view)
    when "csv"
      download_csv(@view)
    end
  end

  # Save column widths
  def save_col_widths
    @view = session[:view]
    #don't do anything if @view is nil, incase user used back button or multiple tabs to access list view screen
    if @view
#   cols_key = @view.scoped_association.nil? ? @view.db.to_sym : (@view.db + "-" + @view.scoped_association).to_sym
    cols_key = create_cols_key(@view)
      if params[:col_widths]
        cws = params[:col_widths].split(",")[2..-1]
        if cws.length > 0
          db_user = User.find_by_userid(session[:userid])
          if db_user != nil
            db_user.settings[:col_widths] ||= Hash.new                        # Create the col widths hash, if not there
            db_user.settings[:col_widths][cols_key] ||= Hash.new        # Create hash for the view db
            @settings[:col_widths] ||= Hash.new                               # Create the col widths hash, if not there
            @settings[:col_widths][cols_key] ||= Hash.new             # Create hash for the view db
            cws.each_with_index do |cw, i|
              @settings[:col_widths][cols_key][@view.col_order[i]] = cw.to_i  # Save each cols width
            end
            db_user.settings[:col_widths][cols_key] = @settings[:col_widths][cols_key]
          end
          db_user.save
        end
      end
    end
    render :nothing => true                                 # No response needed
  end

  ###########################################################################
  # Use ajax to retry until the passed in task is complete, then rerun the original action
  # This action can be called directly or via URL
  # If called directly, options will have the task_id
  # Otherwise, task_id will be in the params
  ###########################################################################
  def wait_for_task
    @edit = session[:edit]  # If in edit, need to preserve @edit object
    raise Forbidden, 'Invalid input for "wait_for_task".' unless params[:task_id]

    @edit = session[:edit]  # If in edit, need to preserve @edit object
    session[:async] ||= {}
    session[:async][:interval] ||= 1000 # Default interval to 1 second
    session[:async][:params]   ||= {}

    if MiqTask.find(params[:task_id].to_i).state != "Finished" # Task not done --> retry
      browser_refresh_task(params[:task_id])
    else                                                  # Task done
      @_params.merge!(session[:async][:params])           # Merge in the original parms and
      send(session.fetch_path(:async, :params, :action))  # call the orig. method
    end
  end

  def browser_refresh_task(task_id)
    session[:async][:interval] += 250 if session[:async][:interval] < 5000    # Slowly move up to 5 second retries
    render :update do |page|
      ajax_call = remote_function(:url => {:action => 'wait_for_task', :task_id => task_id})
      page << "setTimeout(\"#{ajax_call}\", #{session[:async][:interval]});"
    end
  end
  private :browser_refresh_task

  def initiate_wait_for_task(options = {})
    task_id = options[:task_id]
    session[:async] ||= {}
    session[:async][:interval] ||= 1000 # Default interval to 1 second
    session[:async][:params]   ||= {}

    session[:async][:interval]         = options[:retry_seconds] * 1000 if options[:retry_seconds].kind_of?(Numeric)
    session[:async][:params]           = copy_hash(params)  # Save the incoming parms
    session[:async][:params][:task_id] = task_id

    browser_refresh_task(task_id)
  end
  private :initiate_wait_for_task

  def event_logs
    @record = identify_record(params[:id])
    @view = session[:view]                  # Restore the view from the session to get column names for the display
    return if record_no_longer_exists?(@record)

    @lastaction = "event_logs"
    obj = @record.kind_of?(Vm) ? "vm" : "host"
    bc_text = @record.kind_of?(Vm) ? "Event Logs" : "ESX Logs"
    @sb[:action] = params[:action]
    @explorer = true if @record.kind_of?(VmOrTemplate)
    if params[:show] != nil || params[:x_show] != nil
      id = params[:show] ? params[:show] : params[:x_show]
      @item = @record.event_logs.find(from_cid(id))
      drop_breadcrumb( {:name=>@record.name+" (#{bc_text})", :url=>"/#{obj}/event_logs/#{@record.id}?page=#{@current_page}"} )
      drop_breadcrumb( {:name=>@item.name, :url=>"/#{obj}/show/#{@record.id}?show=#{@item.id}"} )
      show_item
    else
      drop_breadcrumb( {:name=>@record.name+" (#{bc_text})", :url=>"/#{obj}/event_logs/#{@record.id}"} )
      @listicon = "event_logs"
      show_details(EventLog, :association=>"event_logs")
    end
  end

  # Handle paging bar controls
  def saved_report_paging
    # Check new paging parms coming in
    if params[:ppsetting]
      @settings[:perpage][:reports] = params[:ppsetting].to_i
      @sb[:pages][:current] = 1
      total = @sb[:pages][:items] / @settings[:perpage][:reports]
      total += 1 if @sb[:pages][:items] % @settings[:perpage][:reports] != 0
      @sb[:pages][:total] = total
    end
    @sb[:pages][:current] = params[:page].to_i if params[:page]
    @sb[:pages][:perpage] = @settings[:perpage][:reports]

    rr = MiqReportResult.find(@sb[:pages][:rr_id])
    @html = report_build_html_table(rr.report_results,
                                    rr.html_rows(:page=>@sb[:pages][:current],
                                                :per_page=>@sb[:pages][:perpage]).join)

    render :update do |page|
      page.replace("report_html_div", :partial=>"layouts/report_html")
      page.replace_html("paging_div",:partial=>'layouts/saved_report_paging_bar', :locals=>{:pages=>@sb[:pages]})
      page << javascript_hide_if_exists("form_buttons_div")
      page << javascript_show_if_exists("rpb_div_1")
      page << "miqSparkle(false)"
    end
  end

  def build_vm_host_array
    @temp[:tree_hosts] = Host.where(:id => (@sb[:tree_hosts_hash] || {}).keys)
    @temp[:tree_vms]   = Vm.where(  :id => (@sb[:tree_vms_hash]   || {}).keys)
  end

  # Show the current widget report in pdf format
  def widget_to_pdf
    @report = nil   #setting report to nil in case full screen mode was opened first, to make sure the one in report_result is used for download
    session[:report_result_id] = params[:rr_id]
    render_pdf
  end

  # Common method to show a standalone report
  def report_only
    @report_only = true                 # Indicate stand alone report for views

    # Dashboard widget will send in report result id else, find report result in the sandbox
    search_id = params[:rr_id] ? params[:rr_id].to_i : @sb[:pages][:rr_id]
    rr = MiqReportResult.find(search_id)

    session[:report_result_id] = rr.id  # Save report result id for render_zgraph
    session[:rpt_task_id]      = nil    # Clear out report task id, using a saved report

    @report   = rr.report
    @html     = report_build_html_table(rr.report_results, rr.html_rows.join)
    @ght_type = params[:type] || (@report.graph.blank? ? 'tabular' : 'hybrid')
    @title    = @report.title

    @zgraph = case @ght_type
              when 'tabular'         then nil
              when 'graph', 'hybrid' then true
              end

    render controller_name == 'report' ? 'show' : 'shared/show_report'
  end

  def show_statistics
    case controller_name
    when "ontap_storage_system"
      db = OntapStorageSystem
    when "ontap_logical_disk"
      db = OntapLogicalDisk
    when "cim_base_storage_extent"
      db = CimBaseStorageExtent
    when "ontap_storage_volume"
      db = OntapStorageVolume
    when "ontap_file_share"
      db = OntapFileShare
    when "snia_local_file_system"
      db = SniaLocalFileSystem
    end

    @display = "show_statistics"
    session[:stats_record_id] = params[:id] if params[:id]
    @record = find_by_id_filtered(db, session[:stats_record_id])

    # Need to use paged_view_search code, once the relationship is working. Following is workaround for the demo
    @stats = @record.derived_metrics
    drop_breadcrumb( {:name=>"Utilization", :url=>"/#{db}/show_statistics/#{@record.id}?refresh=n"} )
    render :action=>"show"

#   generate the grid/tile/list url to come back here when gtl buttons are pressed
#   @gtl_url = "/#{controller_name}/show_statistics/" + @record.id.to_s + "?"#
#    @showtype = "details"#
#   @view, @pages = get_view(db, :parent=>@record, :parent_method => :miq_cim_derived_stats)  # Get the records (into a view) and the paginator
#   @no_checkboxes = true
#   @showlinks = false
  end

  # moved this method here so it can be accessed from pxe_server controller as well
  def log_depot_validate # this is a terrible name, it doesn't validate log_depots
    @schedule = nil # setting to nil, since we are using same view for both db_back and log_depot edit
    # if zone is selected in tree replace tab#3
    if x_active_tree == :diagnostics_tree
      if @sb[:active_tab] == "diagnostics_database"
        #coming from diagnostics/database tab
        pfx = "dbbackup"
        flash_div_num = "database"
      end
    else
      if session[:edit] && session[:edit].key?(:pxe_id)
        #add/edit pxe server
        pfx = "pxe"
        flash_div_num = ""
      else
        #add/edit dbbackup schedule
        pfx = "schedule"
        flash_div_num = ""
      end
    end

    id = params[:id] ? params[:id] : "new"
    if pfx == "pxe"
      return unless load_edit("#{pfx}_edit__#{id}")
      settings = {:username => @edit[:new][:log_userid], :password => @edit[:new][:log_password]}
      settings[:uri] = @edit[:new][:uri_prefix] + "://" + @edit[:new][:uri]
    else
      settings = {:username => params[:log_userid], :password => params[:log_password]}
      settings[:uri] = "#{params[:uri_prefix]}://#{params[:uri]}"
      settings[:uri_prefix] = params[:uri_prefix]
    end

    begin
      if pfx == "pxe"
        msg = 'PXE Credentials successfuly validated'
        PxeServer.verify_depot_settings(settings)
      else
        msg = 'Depot Settings successfuly validated'
        MiqSchedule.new.verify_file_depot(settings)
      end
    rescue StandardError => bang
      add_flash(_("Error during '%s': ") % "Validate" << bang.message, :error)
    else
      add_flash(msg)
    end

    @changed = (@edit[:new] != @edit[:current]) if pfx == "pxe"
    render :update do |page|
      page.replace("flash_msg_div#{flash_div_num}", :partial=>"layouts/flash_msg", :locals=>{:div_num=>flash_div_num})
    end
  end

  #to reload currently displayed summary screen in explorer
  def reload
    @_params[:id] = x_node
    tree_select
  end

  protected

  def render_flash(add_flash_text = nil, severity = nil)
    add_flash(add_flash_text, severity) if add_flash_text
    render :update do |page|
      page.replace("flash_msg_div", :partial => "layouts/flash_msg")
      yield(page) if block_given?
    end
  end

  def tagging_explorer_controller?
    false
  end

  private

  def move_cols_left_right(direction)
    flds = direction == "right" ? "available_fields" : "selected_fields"
    edit_fields = direction == "right" ? "available_fields" : "fields"
    sort_fields = direction == "right" ? "fields" : "available_fields"
    if !params[flds.to_sym] || params[flds.to_sym].length == 0 || params[flds.to_sym][0] == ""
      lr_messages = {
        "left"  => _("No %s were selected to move left"),
        "right" => _("No %s were selected to move right")
      }
      add_flash(lr_messages[direction] % "fields", :error)
    else
      @edit[:new][edit_fields.to_sym].each do |af|                 # Go thru all available columns
        if params[flds.to_sym].include?(af[1].to_s)        # See if this column was selected to move
          unless @edit[:new][sort_fields.to_sym].include?(af)                # Only move if it's not there already
            @edit[:new][sort_fields.to_sym].push(af)                     # Add it to the new fields list
          end
        end
      end
      # Remove selected fields
      @edit[:new][edit_fields.to_sym].delete_if { |af| params[flds.to_sym].include?(af[1].to_s) }
      @edit[:new][sort_fields.to_sym].sort!                  # Sort the selected fields array
      @refresh_div = "column_lists"
      @refresh_partial = "column_lists"
    end
  end

  # Add a picture record id or array of ids to be synced to disk
  def add_pictures_to_sync(pic_ids)
    @pictures_to_sync ||= Array.new
    @pictures_to_sync.push(pic_ids)
    @pictures_to_sync.flatten!
    @pictures_to_sync.uniq!
  end

  # Build a Catalog Items explorer tree
  def build_ae_tree(type = :ae, name = :ae_tree)
    # build the ae tree to show the tree select box for entry point
    if x_active_tree == :automate_tree && @edit && @edit[:new][:fqname]
      nodes = @edit[:new][:fqname].split("/")
      @temp[:open_nodes] = Array.new
      #if there are more than one nested namespaces
      nodes.each_with_index do |node,i|
        if i == nodes.length-1
          #check if @cls is there, to make sure the class/instance still exists in Automate db
          inst = @cls ? MiqAeInstance.find_by_class_id_and_name(@cls.id,nodes[i]) : nil
          #show this as selected/expanded node when tree loads
          @temp[:open_nodes].push("aei-#{inst.id}") if inst
          @temp[:active_node] = "aei-#{to_cid(inst.id)}" if inst
        elsif i == nodes.length-2
          @cls = MiqAeClass.find_by_namespace_id_and_name(@ns.id,nodes[i])
          @temp[:open_nodes].push("aec-#{to_cid(@cls.id)}") if @cls
        else
          @ns = MiqAeNamespace.find_by_name(nodes[i])
          @temp[:open_nodes].push("aen-#{to_cid(@ns.id)}") if @ns
        end
      end
    end

    tree = TreeBuilderAeClass.new(name, type, @sb)
    @temp[:automate_tree] = tree.tree_nodes if name == :automate_tree
    tree
  end

  def set_summary_pdf_data
    @report_only = true
    @showtype    = @display
    run_time     = Time.now
    klass        = ui_lookup(:model => "#{@record.class}")

    @options = {
      :page_layout => "portrait",
      :page_size   => "us-letter",
      :run_date    => run_time.strftime("%m/%d/%y %l:%m %p %z"),
      :title       => "#{klass} \"#{@record.name}\"".html_safe,
    }

    if @display == "download_pdf"
      @display = "main"
      case @record
      when Vm
        if @record.hardware.present?
          @record_notes = @record.hardware.annotation || "<No notes have been entered for this VM>"
        end
        get_host_for_vm(@record)
        set_config(@record)
      when ResourcePool
        # FIXME: check if this can be put before the test (can we have other
        # records than Vm and ResourcePool?)
        set_config(@record)
      end

      disable_client_cache
      html_string = render_to_string(:template => "/layouts/show_pdf", :layout => false)
      pdf_data = PdfGenerator.pdf_from_string(html_string, "pdf_summary")
      send_data(pdf_data,
        :type     => "application/pdf",
        :filename => "#{klass}_#{@record.name}_summary_#{format_timezone(run_time, Time.zone, "fname")}.pdf"
      )
    end
  end

  # moved this method here so it can be accessed from pxe_server controller as well
  def log_depot_set_verify_status
    if (@edit[:new][:log_password] == @edit[:new][:log_verify]) && @edit[:new][:uri_prefix] != "nfs" &&
      (!@edit[:new][:uri].blank? && !@edit[:new][:log_userid].blank? && !@edit[:new][:log_password].blank? && !@edit[:new][:log_verify].blank?)
      @edit[:log_verify_status] = true
    elsif @edit[:new][:uri_prefix] == "nfs" && !@edit[:new][:uri].blank?
      @edit[:log_verify_status] = true
    else
      @edit[:log_verify_status] = false
    end
  end

  # Build an audit object when configuration is changed in configuration and ops controllers
  def build_config_audit(new, current)
    if controller_name == "ops" && @sb[:active_tab] == "settings_server"
      server = MiqServer.find(@sb[:selected_server_id])
      msg = "#{server.name} [#{server.id}] in zone #{server.my_zone} VMDB config updated"
    else
      msg = "VMDB config updated"
    end

    { :event   => "vmdb_config_update",
      :userid  => session[:userid],
      :message => build_audit_msg(new, current, msg)
    }
  end

  def password_field?(k)
    (k.to_s.ends_with?("password") || k.to_s.ends_with?("_pwd") ||
      k.to_s.ends_with?("amazon_secret"))
  end

  def build_audit_msg(new, current, msg_in)
    msg_arr = []
    new.each_key do |k|
      if (!(k.to_s.ends_with?("password2") || k.to_s.ends_with?("verify")) &&
          (current.nil? || (new[k] != current[k])))
        if password_field?(k) # Asterisk out password fields
          msg_arr << "#{k}:[*]#{' to [*]' unless current.nil?}"
        elsif new[k].is_a?(Hash)       # If the field is a hash,
          # Make current a blank hash for following comparisons
          current[k] = Hash.new if (!current.nil? && current[k].nil?)
          #   process keys of the current and new hashes
          (new[k].keys | (current.nil? ? [] : current[k].keys)).each do |hk|
            if current.nil? || (new[k][hk] != current[k][hk])
              if password_field?(hk) # Asterisk out password fields
                msg_arr << "#{hk}:[*]#{' to [*]' unless current.nil?}"
              else
                msg_arr << "#{hk}:[" +
                           (current.nil? ? "" :
                            "#{current[k][hk]}] to [") +
                            "#{new[k][hk]}]"
              end
            end
          end
        else
          msg_arr << "#{k}:[" +
                     (current.nil? ? "" :
                      "#{current[k]}] to [") +
                      "#{new[k]}]"
        end
      end
    end
    "#{msg_in} (#{msg_arr.join(', ')})"
  end

  # Disable client side caching of the response being sent
  def disable_client_cache
    response.headers["Cache-Control"] = "no-cache, no-store, max-age=0, must-revalidate"

    # IE will not allow downloads if no-cache is used because it won't save the file in the temp folder, so use private
    if is_browser_ie?
      response.headers["Pragma"] = "private"
    else
      response.headers["Pragma"] = "no-cache"
    end

    response.headers["Expires"] = "Fri, 01 Jan 1990 00:00:00 GMT"
  end

  # Common method enable/disable schedules
  def schedule_enable_disable(schedules, enabled)
    MiqSchedule.where(:id => schedules, :enabled => !enabled).order("lower(name)").each do |schedule|
      schedule.enabled = enabled
      schedule.save!
    end
  end

  # Build the user_emails hash for edit screens needing the edit_email view
  def build_user_emails_for_edit
    @edit[:user_emails] = Hash.new
    User.all.sort_by { |u| u.name.downcase }.each do |u|
      unless u.email.blank? ||
              (@edit[:new][:email][:to] && @edit[:new][:email][:to].include?(u.email))
        @edit[:user_emails][u.email] = "#{u.name} (#{u.email})"
      end
    end
  end

  # Build the first html page for a report results record
  def report_first_page(rr)
    rr.build_html_rows_for_legacy # Create the report result details for legacy reports
    @report = rr.report # Grab the report, not including table

    @sb[:pages] ||= Hash.new
    @sb[:pages][:rr_id] = rr.id
    @sb[:pages][:items] = @report.extras[:total_html_rows]
    @sb[:pages][:perpage] = @settings[:perpage][:reports]
    @sb[:pages][:current] = 1
    total = @sb[:pages][:items] / @sb[:pages][:perpage]
    total += 1 if @sb[:pages][:items] % @sb[:pages][:perpage] != 0
    @sb[:pages][:total] = total
    title = @report.name
    @title = @report.title
    if @report.extras[:total_html_rows] == 0
      add_flash(_("No records found for this report"), :warning)
      html = nil
    else
      html = report_build_html_table(@report,
                                    rr.html_rows(:page=>@sb[:pages][:current],
                                                :per_page=>@sb[:pages][:perpage]).join)
    end
    return html
  end

  def calculate_lastaction(lastaction)
    return 'show_list' unless lastaction

    parts = lastaction.split('__')
    if parts.first == "replace_cell"
      parts.last
    else
      params[:id] == 'new' ? 'show_list' : lastaction
    end
  end
  private :calculate_lastaction

  def report_edit_aborted(lastaction)
    add_flash(_("Edit aborted!  CFME does not support the browser's back button or access from multiple tabs or windows of the same browser.  Please close any duplicate sessions before proceeding."), :error)
    session[:flash_msgs] = @flash_array.dup
    if request.xml_http_request?  # Is this an Ajax request?
      if lastaction == "configuration"
        edit
        redirect_to_action = 'index'
      else
        redirect_to_action = lastaction
      end
      render :update do |page|
        page.redirect_to :action => redirect_to_action, :id => params[:id], :escape => false, :load_edit_err => true
      end
    else
      redirect_to :action => lastaction, :id => params[:id], :escape => false
    end
  end
  private :report_edit_aborted

  def load_edit(key, lastaction = @lastaction)
    lastaction = calculate_lastaction(lastaction)

    if session.fetch_path(:edit, :key) != key
      report_edit_aborted(lastaction)
      return false
    end

    @edit = session[:edit]
    true
  end

  # Put all time profiles for the current user in session[:time_profiles] for pulldowns
  def get_time_profiles(obj=nil)
    session[:time_profiles] = {}
    region_id = obj ? obj.region_id : MiqRegion.my_region_number
    time_profiles = TimeProfile.profiles_for_user(session[:userid], region_id)
    time_profiles.collect { |tp| session[:time_profiles][tp.id] = tp.description }
  end

  def selected_time_profile_for_pull_down
    tp = TimeProfile.profile_for_user_tz(session[:userid], session[:user_tz])
    tp = TimeProfile.default_time_profile if tp.nil?

    if tp.nil? && !session[:time_profiles].blank?
      first_id_in_hash = Array(session[:time_profiles].invert).sort_by(&:first).first.last
      tp = TimeProfile.find_by_id(first_id_in_hash)
    end
    tp
  end

  def set_time_profile_vars(tp, options)
    if tp
      options[:time_profile]      = tp.id
      options[:time_profile_tz]   = tp.tz
      options[:time_profile_days] = tp.days
    else
      options[:time_profile]      = nil
      options[:time_profile_tz]   = nil
      options[:time_profile_days] = nil
    end
    options[:tz] = options[:time_profile_tz]
  end

  # Create a time in a timezone
  def create_time_in_tz(datetime, tz = nil)               # tz = nil means use user's session timzone
    if tz && (Time.zone == nil  || tz != Time.zone.name)  # If tz passed in and not default tz
      saved_tz = Time.zone
      Time.zone = tz                                      # Temporarily convert to new tz and create the time object
      t = Time.zone.parse(datetime)                       # Create the time object
      Time.zone = saved_tz                                # Restore original default
    else                                                  # tz not passed in or matches current tz
      t = Time.zone.parse(datetime)                       # Create the time object
    end
    return t
  end

  # Create a time in a timezone, return in UTC
  def create_time_in_utc(datetime, tz = nil)                        # tz = nil means use user's session timzone
    return create_time_in_tz(datetime, tz).in_time_zone("Etc/UTC")  # Return the time in UTC
  end

  # convert time from utc to server timezone
  def convert_time_from_utc(datetime)
    tz = MiqServer.my_server.get_config("vmdb").config.fetch_path(:server, :timezone)
    tz = "UTC" if tz.blank?
    return datetime.in_time_zone(tz)
  end

  def set_user_time_zone
    # if authenticating or past login screen
    @tz = if session[:userid].present? || params[:user_name].present?
            get_timezone_for_userid(session[:userid] || params[:user_name])
          else
            MiqServer.my_server.get_config("vmdb").config.fetch_path(:server, :timezone)
          end

    @tz ||= 'UTC'

    session[:user_tz] = Time.zone = @tz
  end

  # Initialize the options for server selection
  def init_server_options(show_all = true)
    @server_options ||= Hash.new
    @server_options[:zones] = Array.new
    @server_options[:zone_servers] = Hash.new
    MiqServer.all.each do |ms|
      if show_all || ms.started?                                                          # Collect all or only started servers
        if ms.id == MiqServer.my_server.id                                                # This is the current server
          @server_options[:server_id] ||= ms.id
          next                                                                            # Don't add to list
        end
        name = "#{ms.name} [#{ms.id}]"
        @server_options[:zones].push(ms.my_zone) unless @server_options[:zones].include?(ms.my_zone)  # Collect all of the zones
        @server_options[:zone_servers][ms.my_zone] ||= Array.new                                # Initialize zone servers array
        @server_options[:zone_servers][ms.my_zone].push(ms.id)                                # Add server to the zone
      end
    end
    @server_options[:server_id] ||= MiqServer.my_server.id
    @server_options[:zone] = MiqServer.find(@server_options[:server_id]).my_zone
    @server_options[:hostname] = ""
    @server_options[:ipaddress] = ""
  end

  #Gather information for the report accordians
  def build_report_listnav(tree_type="reports",tree="listnav",mode="menu")
    #checking to see if group (used to be role) was selected in menu editor tree, or came in from reports/timeline tree calls
    group = !session[:role_choice].blank? ? MiqGroup.find_by_description(session[:role_choice]).id : session[:group]
    @sb[:rpt_menu] = get_reports_menu(group,tree_type,mode)
    if tree == "listnav"
      if tree_type == "timeline"
        build_timeline_tree(@sb[:rpt_menu],tree_type)
      else
        build_reports_tree(:reports,:reports_tree)
      end
    else
      build_menu_tree(@sb[:rpt_menu],tree_type)
    end
  end

  def get_reports_menu(group=session[:group], tree_type="reports", mode="menu")
    rptmenu = Array.new
    reports = Array.new
    folders = Array.new
    rec = MiqGroup.find_by_id(group)
    user = User.find_by_userid(session[:userid])
    @sb[:grp_title] = user.admin_user? ?
      "#{session[:customer_name]} (#{_("All %s") % ui_lookup(:models=>"MiqGroup")})" :
      "#{session[:customer_name]} (#{_("%s") % "#{ui_lookup(:model=>"MiqGroup")}: #{user.current_group.description}"})"
    @data = Array.new
    if (!rec.settings || !rec.settings[:report_menus] || rec.settings[:report_menus].blank?) || mode == "default"
      #array of all reports if menu not configured
      @rep = MiqReport.all.sort_by { |r| [r.rpt_type, r.filename.to_s, r.name] }
      if tree_type == "timeline"
        @data = @rep.reject { |r| r.timeline.nil? }
      else
        @data = @rep.select do |r|
          r.template_type == "report" && !r.template_type.blank?
        end
      end
      @data.each do |r|
        next if r.template_type != "report" && ! r.template_type.blank?
        r_group = r.rpt_group == "Custom" ? "#{@sb[:grp_title]} - Custom" : r.rpt_group # Get the report group
        title = r_group.split('-').collect(&:strip)
        if @temp_title != title[0]
          @temp_title = title[0]
          reports = Array.new
          folders = Array.new
        end

        if title[1].nil?
          if title[0] == @temp_title
            reports.push(r.name) unless reports.include?(r.name)
            rptmenu.push([title[0],reports]) unless rptmenu.include?([title[0],reports])
          end
        else
          if @temp_title1 != title[1]
            reports = Array.new
            @temp_title1 = title[1]
          end
          rptmenu.push([title[0],folders]) unless rptmenu.include?([title[0],folders])
          if user.admin_user?
            #for admin user show all the reports
            reports.push(r.name) unless reports.include?(r.name)
          else
            #for non admin users, only show custom reports for their group
            if title[1] == "Custom"
              reports.push(r.name) if !reports.include?(r.name) && (r.miq_group && user.current_group.id == r.miq_group.id)
            else
              reports.push(r.name) unless reports.include?(r.name)
            end
          end
          folders.push([title[1],reports]) unless folders.include?([title[1],reports])
        end
      end
    else
      # Building custom reports array for super_admin/admin roles, it doesnt show up on menu if their menu was set which didnt contain custom folder in it
      temp = Array.new
      subfolder = %w{ Custom }
      @custom_folder = [ @sb[:grp_title] ]
      @custom_folder.push([subfolder]) unless @custom_folder.include?([subfolder])

      custom = MiqReport.all.sort_by { |r| [r.rpt_type, r.filename.to_s, r.name] }
      rep = custom.select do |r|
        r.rpt_type == "Custom" && (user.admin_user? || r.miq_group_id.to_i == session[:group].to_i)
      end.map(&:name).uniq

      subfolder.push(rep) unless subfolder.include?(rep)
      temp.push(@custom_folder) unless temp.include?(@custom_folder)
      if tree_type == "timeline"
        temp2 = []
        rec.settings[:report_menus].each do |menu|
          folder_arr = Array.new
          menu_name = menu[0]
          menu[1].each_with_index do |reports,i|
            reports_arr = Array.new
            folder_name = reports[0]
            reports[1].each do |rpt|
              r = MiqReport.find_by_name(rpt)
              if r && r.timeline != nil
                temp2.push([menu_name,folder_arr]) unless temp2.include?([menu_name,folder_arr])
                reports_arr.push(rpt) unless reports_arr.include?(rpt)
                folder_arr.push([folder_name,reports_arr]) unless folder_arr.include?([folder_name,reports_arr])
              end
            end
          end
        end
      else
        temp2 = rec.settings[:report_menus]
      end
      rptmenu = temp.concat(temp2)
    end
    #move Customs folder as last item in tree
    rptmenu[0].each do |r|
      if r.class == String && r == @sb[:grp_title]
        @custom_folder = copy_array(rptmenu[0]) if @custom_folder.nil?
        #Keeping My Company Reports folder on top of the menu tree only if user is on edit tab, else delete it from tree
        #only add custom folder if it has any reports
        rptmenu.push(rptmenu[0]) if !rptmenu[0][1][0][1].empty?
        rptmenu.delete_at(0)
      end
    end
    return rptmenu
  end

  # Render the view data to xml for the grid view
  def view_to_xml(view, from_idx = 0, to_idx = -1, options = {})
    # Get the time zone in effect for this view
    if view.db.downcase == 'miqschedule'
      tz = MiqServer.my_server.get_config("vmdb").config.fetch_path(:server, :timezone) || "UTC"
    else
      tz = Time.zone
    end

    xml = MiqXml.createDoc(nil, nil, 1.0, :nokogiri)

    root = xml.add_element('rows')

    head = root.add_element('head')

    # Show checkbox or placeholder column
    unless @embedded || @no_checkboxes
      head.add_element('column', 'type' => 'ch', 'width' => 25, 'align' => 'center')
    else
      head.add_element('column', 'type' => 'ro', 'width' => 1, 'align' => 'center')
    end

    unless %w(miqaeclass miqaeinstance).include?(view.db.downcase)  # do not add listicon for AE class show_list
      head.add_element('column', 'type' => 'ro', 'width' => 36, 'align' => 'center')  # Icon column
    end

    cols_key = create_cols_key(view)
    view.headers.each_with_index do |h,i|
      col_width = 900 / view.headers.length # Set default column width
      col_width = 100 if h.downcase == 'cost' && view.db.to_s == 'ServiceTemplate'

      # Load saved width, if present
      col_width = @settings.fetch_path(:col_widths, cols_key, view.col_order[i]) || col_width

      align = [:fixnum, :integer, :Fixnum, :float].include?(column_type(view.db, view.col_order[i])) ? 'right' : 'left'
      new_column = head.add_element('column',
                                    'width' => col_width.to_s,
                                    'sort'  => 'str',
                                    'type'  => 'ro',
                                    'align' => align)
      new_column.text = h
    end

    if @row_button  # Show a button as last col
      head.add_element('column', 'type' => 'ro', 'width' => 100, 'align' => 'center')
    end

    # Add table elements
    table = view.sub_table ? view.sub_table : view.table
    table.data[from_idx..to_idx].each do |row|
      @id = row['id']

      new_row = root.add_element('row', "id" => list_row_id(row))
      new_row.add_element('cell').text = '0'  # Checkbox column unchecked

      # Generate html for the list icon
      # do not add listicon for AE class show_list
      unless %w(miqaeclass miqaeinstance).include?(view.db.downcase)
        cell = new_row.add_element('cell', 'title' => 'View this item')
        cell.add_cdata("<img src='#{listicon_image(view)}' width='20' height='20' border='0' align='middle' alt='Image missing'>")
      end

      view.col_order.each_with_index do |col, col_idx|
        cell = new_row.add_element('cell')
        celltext = nil
        case view.col_order[col_idx]
        when 'db'
          celltext = Dictionary.gettext(row[col], :type => :model, :notfound => :titleize)
        when 'approval_state'
          celltext = PROV_STATES[row[col]]
        when 'state'
          celltext = row[col].titleize
        when 'hardware.bitness'
          celltext = row[col].nil? ? row[col] : "#{row[col]} bit"
        else
          # Use scheduled tz for formatting, if configured
          if ['miqschedule'].include?(view.db.downcase)
            celltz = row['run_at'][:tz] if row['run_at'] && row['run_at'][:tz]
          end
          celltext = escape_once(format_col_for_display(view, row, col, celltz || tz))
        end
        cell.text = celltext # Put value into the cell
      end

      if @row_button # Show a button in the last col
        cell = new_row.add_element('cell', 'title' => @row_button[:title], 'is_button' => 1)
        cell.add_cdata("<button class   = 'btn btn-primary btn-xs'
                                title   = '#{@row_button[:title]}'
                                onclick = '#{@row_button[:function]}(\"#{@id}\");'
                                alt     = '#{@row_button[:title]}'>#{@row_button[:image]}
                        </button>")
      end
    end

    # Use write method with -1 so the xml string is not indented
    xml.write(xml_str = '', -1)
    return xml_str
  end

  # Create a hash key to store a views column widths
  def create_cols_key(view)
    key = view.scoped_association.nil? ? view.db : (view.db + "-" + view.scoped_association)
    # For certain models, save columns for each tree that uses the view
    key += ("-" + x_active_tree.to_s) if ("ServiceTemplate" == view.db) && x_active_tree
    key.to_sym
  end

  def calculate_pct_img(val)
    val == 100 ? 20 : ((val + 2) / 5.25).round # val is the percentage value of free space
  end

  # Return the image name for the list view icon of a db,id pair
  def listicon_image(view)
    item = if @targets_hash
             @targets_hash[@id] # Get the record from the view
           else
             klass = view.db.constantize
             klass.find(@id)    # Read the record from the db
           end

    p  = "/images/icons/"
    pn = "#{p}new/"

    image = case item
            when ExtManagementSystem   then "#{pn}/vendor-#{item.image_name}.png"
            when Filesystem            then "#{p}ico/win/#{item.image_name.downcase}.ico"
            when Host                  then "#{pn}vendor-#{item.vmm_vendor.downcase}.png"
            when MiqEvent              then "#{pn}event-#{item.name.downcase}.png"
            when MiqRequest
              pn + case item.request_status.to_s.downcase
                   when "ok"    then "checkmark.png"
                   when "error" then "x.png"
                   else              "#{@listicon.downcase}.png"
                   end
            when RegistryItem          then "#{pn}#{item.image_name.downcase}.png"
            when ResourcePool          then "#{pn}#{item.vapp ? "vapp" : "resource_pool"}.png"
            when VmOrTemplate          then "#{pn}vendor-#{item.vendor.downcase}.png"
            when ServiceResource       then "#{pn}#{item.resource_type.to_s == "VmOrTemplate" ? "vm" : "service_template"}.png"
            when Storage               then "#{pn}piecharts/datastore/#{calculate_pct_img(item.v_free_space_percent_of_total)}.png"
            when OsProcess, EventLog   then "#{pn}#{@listicon.downcase}.png"
            when Service, ServiceTemplate
              if item.try(:picture)
                add_pictures_to_sync(item.picture.id)
                "../../../pictures/#{item.picture.basename}"
              end
            end
    list_row_image(pn, image, (@listicon || view.db).underscore, item.name)
  end

  def get_host_for_vm(vm)
    @hosts = [vm.host] if vm.host
  end

  def download_txt(view)
    disable_client_cache
    send_data(view.to_text, :filename => "#{@filename}.txt")
  end

  def download_csv(view)
    disable_client_cache
    send_data(view.to_csv, :filename => "#{@filename}.csv")
  end

  # Send the current report in pdf format
  def download_pdf(view)
    render_pdf(view)
  end

  # Add a msg to the @flash_array
  def add_flash(msg, level = :info, reset = false)
    @flash_array = [] if reset
    @flash_array ||= []
    @flash_array.push({:message => msg, :level => level})

    case level
    when :error
      $log.error("MIQ(#{controller_name}_controller-#{action_name}): " + msg)
    when :warning, :info
      $log.debug("MIQ(#{controller_name}_controller-#{action_name}): " + msg)
    end
  end

  def flash_errors?
    Array(@flash_array).any? { |f| f[:level] == :error }
  end

  # Handle the breadcrumb array by either adding, or resetting to, the passed in breadcrumb
  def drop_breadcrumb(new_bc, onlyreplace=false) # if replace = true, only add this bc if it was already there
    # if the breadcrumb is in the array, remove it and all below by counting how many to pop
    remove = 0
    @breadcrumbs.each do |bc|
      if remove > 0         # already found a match,
        remove += 1       #   increment pop counter
      else
        # Check for a name match BEFORE the first left paren "(" or a url match BEFORE the last slash "/"
        if bc[:name].to_s.gsub(/\(.*/,"").rstrip == new_bc[:name].to_s.gsub(/\(.*/,"").rstrip ||
            bc[:url].to_s.gsub(/\/.?$/,"") == new_bc[:url].to_s.gsub(/\/.?$/,"")
          remove = 1
        end
      end
    end
    remove.times {@breadcrumbs.pop} # remove found element and any lower elements
    if onlyreplace                                              # if replacing,
      @breadcrumbs.push(new_bc) if remove > 0 # only add it if something was removed
    else
      @breadcrumbs.push(new_bc)
    end
    if (@lastaction == "registry_items" || @lastaction == "filesystems" || @lastaction == "files") && new_bc[:name].length > 50
      @title = new_bc [:name].slice(0..50) + "..."  # Set the title to be the new breadcrumb
    else
      @title = new_bc [:name] # Set the title to be the new breadcrumb
    end
  end

  def handle_invalid_session
    timed_out = PrivilegeCheckerService.new.user_session_timed_out?(session)
    reset_session

    session[:start_url] = if RequestRefererService.access_whitelisted?(request, controller_name, action_name)
                            url_for(:controller => controller_name,
                                    :action     => action_name,
                                    :id         => params[:id])
                          end

    respond_to do |format|
      format.html do
        redirect_to :controller => 'dashboard', :action => 'login', :timeout => timed_out
      end

      format.json do
        render :nothing => true, :status => :unauthorized
      end

      format.js do
        render :update do |page|
          page.redirect_to :controller => 'dashboard', :action => 'login', :timeout => timed_out
        end
      end
    end
  end

  def rbac_free_for_custom_button?(task, button_id)
    task == "custom_button" && CustomButton.find_by_id(from_cid(button_id))
  end

  def check_button_rbac
    task = params[:pressed]
    # Intentional single = so we can check auth later
    rbac_free_for_custom_button?(task, params[:button_id]) || role_allows(:feature => task)
  end

  def handle_button_rbac
    pass = check_button_rbac
    unless pass
      add_flash(_("The user is not authorized for this task or item."), :error)
      render_flash
    end
    pass
  end

  def check_generic_rbac
    ident = "#{controller_name}_#{action_name}"
    if MiqProductFeature.feature_exists?(ident)
      role_allows(:feature => ident, :any => true)
    else
      true
    end
  end

  def handle_generic_rbac
    pass = check_generic_rbac
    unless pass
      if request.xml_http_request?
        render :update do |page|
          page.redirect_to(:controller => 'dashboard', :action => 'auth_error')
        end
      else
        redirect_to(:controller => 'dashboard', :action => 'auth_error')
      end
    end
    pass
  end

  # used as a before_filter for controller actions to check that
  # the currently logged in user has rights to perform the requested action
  def check_privileges
    unless PrivilegeCheckerService.new.valid_session?(session)
      handle_invalid_session
      return
    end

    return if action_name == 'auth_error'

    if RequestRefererService.allowed_access?(request, controller_name, action_name, session['referer'])
      # if we came in directly and were allowed then
      # we need to make sure we have the referer in the session for future requests
      session['referer'] = request.base_url + '/' unless session['referer'].present?
    else
      render :status => :forbidden, :text => ''
      return
    end

    pass = %w(button x_button).include?(action_name) ? handle_button_rbac : handle_generic_rbac
    $audit_log.failure("Username [#{session[:userid]}], Role ID [#{User.current_user.miq_user_role.try(:id)}] attempted to access area [#{controller_name}], type [Action], task [#{action_name}]") unless pass
  end

  def cleanup_action
    session[:lastaction] = @lastaction if @lastaction
  end

  # get the default column titles from a db table
  def get_column_titles(db)
    @col_titles = Array.new
    @col_names = Array.new
    db.content_columns.each do | col |

      next if ["guid", "set_type"].include?(col.name)   # Never show GUIDs or Set Types

      # Remove columns based on model
      if db == Host
        next if ["settings", "policy_settings", "vmm_buildnumber", "updated_on","guid"].include?(col.name)
      elsif db == ExtManagementSystem
        next if ["updated_on"].include?(col.name)
      elsif db == Service
        next if ["icon"].include?(col.name)
      elsif db == Vm
        next if ["vendor", "format", "version", "description", "config_xml", "busy", "registered", "autostart", "smart"].include?(col.name)
      elsif db == GuestApplication
        if Regexp.new(/linux/).match(@vm.os_image_name.downcase)
          next if ["product_icon", "transform", "product_key"].include?(col.name)
        end
      elsif db == SystemService
        if Regexp.new(/linux/).match(@vm.os_image_name.downcase)
          next if ["svc_type", "start", "object_name", "depend_on_service", "depend_on_group","typename","display_name"].include?(col.name)
        else
          next if ["enable_run_levels", "disable_run_levels","typename"].include?(col.name)
        end
      elsif db == Job
        next if ["guid", "code", "process", "target_class", "type"].include?(col.name)
      elsif db == MiqPolicySet
        next if ["created_on", "updated_on"].include?(col.name)
      elsif db == PolicySet
        next if ["created_on", "updated_on"].include?(col.name)
      elsif db == MiqPolicy
        next if ["file_mtime", "file_type", "created_on", "updated_on", "_policy", "expression", "towhat"].include?(col.name)
      elsif db == Policy
        next if ["file_mtime", "file_type", "created_on", "updated_on", "_policy", "expression", "towhat"].include?(col.name)
      elsif db == MiqEvent
        next if ["name", "created_on", "updated_on"].include?(col.name)
      elsif db == ConditionSet
        next if ["created_on", "updated_on"].include?(col.name)
      elsif db == Condition
        next if ["file_mtime", "file_type", "created_on", "updated_on", "expression", "towhat", "modifier"].include?(col.name)
      elsif db == MiqAction
        next if ["created_on", "updated_on"].include?(col.name)
      elsif db == ActionSet
        next if ["created_on", "updated_on"].include?(col.name)
      end

      @col_names.push(col.name)   # Move in the column name

      if db == Host               # Replace certain Host columns
        case col.name
          when "hostname"
            @col_titles.push("Host Name")
          when "ipaddress"
            @col_titles.push("IP Address")
          when "vmm_vendor"
            @col_titles.push("VMM Vendor")
          when "vmm_version"
            @col_titles.push("VMM Version")
          when "vmm_product"
            @col_titles.push("VMM Product")
          when "created_on"
            @col_titles.push("Registered On")
          when "last_heartbeat"
            @col_titles.push("Last SmartProxy Heartbeat")
          when "version"
            @col_titles.push("SmartProxy Version")
          else
            @col_titles.push(col.human_name.titleize)
        end
      elsif db == ExtManagementSystem   # Replace certain EMS columns
        case col.name
        when "hostname"
          @col_titles.push("Host Name")
        when "ipaddress"
          @col_titles.push("IP Address")
        when "emstype"
          @col_titles.push("MS Type")
        when "created_on"
          @col_titles.push("Registered On")
        else
          @col_titles.push(col.human_name.titleize)
        end
      elsif db == Vm                  # Replace certain Vm columns
        case col.name
          when "last_extract_time"
            @col_titles.push("Last Extract Time")
          when "last_sync_on"
            @col_titles.push("Last Sync")
          when "created_on"
            @col_titles.push("Registered On")
          when "updated_on"
            @col_titles.push("Updated On")
          else
            @col_titles.push(col.human_name.titleize)
        end
      elsif db == Job               # Replace certain Job columns
        case col.name
        when "name"
          @col_titles.push("Task Name")
        when "userid"
          @col_titles.push("User")
        when "created_on"
          @col_titles.push("Since Started")
        when "updated_on"
          @col_titles.push("Since Updated")
        when "agent_class"          # Will show the actual agent in this column
          @col_titles.push("SmartProxy")
        when "agent_state"          # Will show the actual agent in this column
          @col_titles.push("SmartProxy State")
        when "agent_message"          # Will show the actual agent in this column
          @col_titles.push("SmartProxy Message")
        else
          @col_titles.push(col.human_name.titleize)
        end
      else
        @col_titles.push(col.human_name.titleize)
      end
    end

    return @col_titles, @col_names  # Return the column titles and names

  end

  # get the sort column that was clicked on, else use the current one
  def get_sort_col
    unless params[:sortby] == nil
      if @sortcol == params[:sortby].to_i                       # if same column was selected
        @sortdir = flip_sort_direction(@sortdir)
      else
        @sortdir = "ASC"
      end
      @sortcol = params[:sortby].to_i
    end
    # in case sort column is not set, set the defaults
    if @sortcol == nil
      @sortcol = 0
      @sortdir = "ASC"
    end
    return @sortcol
  end

  # set up info for the _config partial
  def set_config(db_record) # pass in the db record, either @host or @vm
    @devices = Array.new    # This will be an array of hashes to allow the rhtml to pull out each device field by name
    unless db_record.hardware.nil?
      db_notes = db_record.hardware.annotation.nil? ? "<No notes have been entered for this VM>" : db_record.hardware.annotation

      if db_record.hardware.logical_cpus
        cpu_details =
          if db_record.respond_to?(:num_cpu) && db_record.num_cpu && db_record.respond_to?(:cores_per_socket) && db_record.cores_per_socket
            " (#{pluralize(@record.num_cpu, 'socket')} x #{pluralize(@record.cores_per_socket, 'core')})"
          else
            ""
          end

        @devices.push(:device      => "Processors",
                      :description => "#{db_record.hardware.logical_cpus}#{cpu_details}",
                      :icon        => "processor")
      end

      @devices.push(:device      => "CPU Type",
                    :description => db_record.hardware.cpu_type,
                    :icon        => "processor") if db_record.hardware.cpu_type
      @devices.push(:device      => "CPU Speed",
                    :description => "#{db_record.hardware.cpu_speed} MHz",
                    :icon        => "processor") if db_record.hardware.cpu_speed
      @devices.push(:device      => "Memory",
                    :description => "#{db_record.hardware.memory_cpu} MB",
                    :icon        => "memory") if db_record.hardware.memory_cpu

      # Add disks to the device array
      if !db_record.hardware.disks.nil?
        db_record.hardware.disks.each do |disk|
          loc = disk.location.nil? ? "" : disk.location
          dev = disk.controller_type ? disk.controller_type << " " << loc : ""  # default device is controller_type
          desc = disk.filename                              # default description is filename
          icon = disk.device_name                       # default icon prefix is device_name
          conn = disk.start_connected ? ", Connect at Power On = Yes" : ", Connect at Power On = No"
          # Customize disk entries by type
          if disk.device_type == "cdrom-raw"
            dev = "CD-ROM (IDE " << loc << ")" << conn
            icon = "cdrom"
          elsif disk.device_type == "atapi-cdrom"
            dev = "ATAPI CD-ROM (IDE " << loc << ")" << conn
            icon = "cdrom"
          elsif disk.device_type == "cdrom-image"
            dev = "CD-ROM Image (IDE " << loc << ")" << conn
            icon = "cdrom"
          elsif disk.device_type == "disk"
            icon = "disk"
            if disk.controller_type == "ide"
              dev = "Hard Disk (IDE " << loc << ")"
            elsif disk.controller_type == "scsi"
              dev = "Hard Disk (SCSI " << loc << ")"
              icon = "scsi"
            end
            dev << ", Size: " + number_to_human_size(disk.size,:precision=>2) if disk.size != nil
            dev << ", Size on disk: " + number_to_human_size(disk.size_on_disk,:precision=>2) if disk.size_on_disk != nil
            dev << ", Percent Used Provisioned Space: " + disk.used_percent_of_provisioned.to_s + "%" if disk.used_percent_of_provisioned != nil
            desc << ", Mode: " + disk.mode if disk.mode != nil
          elsif disk.device_type == "ide"
            dev = "Hard Disk (IDE " << loc << ")"
            dev << ", Size: " + number_to_human_size(disk.size,:precision=>2) if disk.size != nil
            dev << ", Size on disk: " + number_to_human_size(disk.size_on_disk,:precision=>2) if disk.size_on_disk != nil
            dev << ", Percent Used Provisioned Space: " + disk.used_percent_of_provisioned.to_s + "%" if disk.used_percent_of_provisioned != nil
            desc << ", Mode: " + disk.mode if disk.mode != nil
            icon = "disk"
          elsif ["scsi", "scsi-hardDisk"].include?(disk.device_type)
            dev = "Hard Disk (SCSI " << loc << ")"
            dev << ", Size: " + number_to_human_size(disk.size,:precision=>2) if disk.size != nil
            dev << ", Size on disk: " + number_to_human_size(disk.size_on_disk,:precision=>2) if disk.size_on_disk != nil
            dev << ", Percent Used Provisioned Space: " + disk.used_percent_of_provisioned.to_s + "%" if disk.used_percent_of_provisioned != nil
            desc << ", Mode: " + disk.mode if disk.mode != nil
            icon = "scsi"
          elsif disk.device_type == "scsi-passthru"
            dev = "Generic SCSI (" << loc << ")"
            icon = "scsi"
          elsif disk.device_type == "floppy"
            dev += conn
            icon = "floppy"
          end
          # uppercase the first character of the device name and description
          dev = dev[0..0].upcase + dev[1..-1]
          desc = desc.nil? ? "" : desc[0..0].upcase + desc[1..-1].to_s

          @devices.push({ :device => dev,
                          :description => desc,
                          :icon => icon })
        end
      end

      # Add ports to the device array
      if !db_record.hardware.ports.nil?
        db_record.hardware.ports.each do |port|
          loc = port.location.nil? ? "" : port.location
          loc = loc.strip == "0" ? "" : loc.next
          dev = port.controller_type << " " << loc
          desc = port.filename.nil? ? "" : port.filename
          icon = port.device_type
          # Customize port entries by type
          if port.device_type == "sound"
            dev = "Audio"
            desc = port.auto_detect.nil? ? "" : "Default Adapter"
          end
          # uppercase the first character of the device name and description
          dev = dev[0..0].upcase + dev[1..-1]
          desc = desc[0..0].upcase + desc[1..-1] if desc.length > 0
          @devices.push({ :device => dev,
                          :description => desc,
                          :icon => icon })
        end
      end
    end

    unless db_record.operating_system.nil?
      @osinfo = Array.new   # This will be an array of hashes to allow the rhtml to pull out each field by name
      @account_policy = Array.new   # This will be an array of hashes to allow the rhtml to pull out each field by name for account policy
      # add OS entry to the array
      @osinfo.push({  :osinfo => "Operating System",
                            :description => db_record.operating_system.product_name
                        }) unless db_record.operating_system.product_name.nil?
      @osinfo.push({  :osinfo => "Service Pack",
                            :description => db_record.operating_system.service_pack
                        }) unless db_record.operating_system.service_pack.nil?
      @osinfo.push({  :osinfo => "Product ID",
                            :description => db_record.operating_system.productid
                        }) unless db_record.operating_system.productid.nil?
      @osinfo.push({  :osinfo => "Version",
                            :description => db_record.operating_system.version
                        }) unless db_record.operating_system.version.nil?
      @osinfo.push({  :osinfo => "Build Number",
                            :description => db_record.operating_system.build_number
                        }) unless db_record.operating_system.build_number.nil?
      @osinfo.push({  :osinfo => "System Type",
                            :description => db_record.operating_system.bitness.to_s + "-bit OS"
                        }) unless db_record.operating_system.bitness.nil?
      @account_policy.push({ :field => "Password History",
                              :description => db_record.operating_system.pw_hist
                            }) unless db_record.operating_system.pw_hist.nil?
      @account_policy.push({ :field => "Max Password Age",
                              :description => db_record.operating_system.max_pw_age
                            }) unless db_record.operating_system.max_pw_age.nil?
      @account_policy.push({ :field => "Min Password Age",
                              :description => db_record.operating_system.min_pw_age
                            }) unless db_record.operating_system.min_pw_age.nil?
      @account_policy.push({ :field => "Min Password Length",
                              :description => db_record.operating_system.min_pw_len
                            }) unless db_record.operating_system.min_pw_len.nil?
      @account_policy.push({ :field => "Password Complex",
                              :description => db_record.operating_system.pw_complex
                            }) unless db_record.operating_system.pw_complex.nil?
      @account_policy.push({ :field => "Password Encrypt",
                              :description => db_record.operating_system.pw_encrypt
                            }) unless db_record.operating_system.pw_encrypt.nil?
      @account_policy.push({ :field => "Lockout Threshold",
                              :description => db_record.operating_system.lockout_threshold
                            }) unless db_record.operating_system.lockout_threshold.nil?
      @account_policy.push({ :field => "Lockout Duration",
                              :description => db_record.operating_system.lockout_duration
                            }) unless db_record.operating_system.lockout_duration.nil?
      @account_policy.push({ :field => "Reset Lockout Counter",
                              :description => db_record.operating_system.reset_lockout_counter
                            }) unless db_record.operating_system.reset_lockout_counter.nil?
      end
    if db_record.respond_to?("vmm_vendor") # For Host table, this will pull the VMM fields
      @vmminfo = Array.new    # This will be an array of hashes to allow the rhtml to pull out each field by name

      @vmminfo.push({:vmminfo => "Vendor",
                              :description => db_record.vmm_vendor
                          }) unless db_record.vmm_vendor.nil?
      @vmminfo.push({:vmminfo => "Product",
                              :description => db_record.vmm_product
                          }) unless db_record.vmm_product.nil?
      @vmminfo.push({:vmminfo => "Version",
                              :description => db_record.vmm_version
                          }) unless db_record.vmm_version.nil?
      @vmminfo.push({:vmminfo => "Build Number",
                             :description => db_record.vmm_buildnumber
                            }) unless db_record.vmm_buildnumber.nil?
    end

    if db_record.respond_to?("vendor") # For Vm table, this will pull the vendor and notes fields
      @vmminfo = Array.new    # This will be an array of hashes to allow the rhtml to pull out each field by name

      @vmminfo.push({:vmminfo => "Vendor",
                              :description => db_record.vendor
                          }) unless db_record.vendor.nil?
      @vmminfo.push({:vmminfo => "Format",
                              :description => db_record.format
                          }) unless db_record.format.nil?
      @vmminfo.push({:vmminfo => "Version",
                              :description => db_record.version
                          }) unless db_record.version.nil?
      unless db_record.hardware.nil?
        notes = db_record.hardware.annotation.nil? ? "<No notes have been entered for this VM>" : db_record.hardware.annotation
        @vmminfo.push({:vmminfo => "Notes",
                                :description => notes
                              })
      end
    end
  end # set_config

  # Common routine to find checked items on a page (checkbox ids are "check_xxx" where xxx is the item id or index)
  def find_checked_items(prefix = nil)
    unless params[:miq_grid_checks].blank?
      return params[:miq_grid_checks].split(",").collect{|c| from_cid(c)}
    else
      prefix = "check" if prefix == nil
      items = Array.new
      session[:base_miq] = ""
      params.each do |var, val|
        vars = var.to_s.split("_")
        if vars[0]==prefix && val=="1"
          ids = vars[1..-1].collect{|v| v = from_cid(v)}  # Decompress any compressed ids
          items.push(ids.join("_"))
        end
      end
      return items
    end
  end

  # Common Saved Reports button handler routines
  def process_saved_reports(saved_reports, task)
    success_count = 0
    failure_count = 0
    MiqReportResult.find_all_by_id(saved_reports, :order => "lower(name)").each do |rep|
      id = rep.id
      rep_name = rep.name
      if task == "destroy"
        audit = {:event=>"rep_record_delete", :message=>"[#{rep_name}] Record deleted", :target_id=>id, :target_class=>"MiqReportResult", :userid => session[:userid]}
      end
      begin
        rep.public_send(task.to_sym) if rep.respond_to?(task)    # Run the task
      rescue StandardError => bang
        failure_count += 1  # Push msg and error flag
      else
        if task == "destroy"
          AuditEvent.success(audit)
          success_count += 1
        else
          add_flash(_("\"%{record}\": %{task} successfully initiated") % {:record=>rep_name, :task=>task})
        end
      end
    end
    if success_count > 0
      add_flash(_("Successfully deleted %s from the CFME Database") % pluralize(success_count,"Saved Report"))
    end
    if failure_count > 0
      add_flash(_("Error during %s delete from the CFME Database") % pluralize(failure_count,"Saved Report"))
    end
  end

  # Common timeprofiles button handler routines
  def process_timeprofiles(timeprofiles, task)
    process_elements(timeprofiles, TimeProfile, task)
  end

  def filter_ids_in_region(ids, label)
    in_reg, out_reg = ActiveRecord::Base.partition_ids_by_remote_region(ids)
    if ids.length == 1
      add_flash(_("The selected %s is not in the current region") % label, :error) if in_reg.empty?
    elsif in_reg.empty?
      add_flash(_("All selected %s are not in the current region") % label.pluralize, :error)
    else
      add_flash(out_reg.length == 1 ?
          _("%s is not in the current region and will be skipped") % pluralize(out_reg.length, label) :
          _("%s are not in the current region and will be skipped") % pluralize(out_reg.length, label), :error) unless out_reg.empty?
    end
    return in_reg, out_reg
  end

  def minify_ar_object(object)
    { :class => object.class.name, :id => object.id }
  end

  def get_view_calculate_gtl_type(db_sym)
    gtl_type = @settings.fetch_path(:views, db_sym) unless %w(scanitemset miqschedule pxeserver customizationtemplate).include?(db_sym.to_s)
    gtl_type = 'grid' if ['vm'].include?(db_sym.to_s) && request.parameters[:controller] == 'service'
    gtl_type ||= 'list' # return a sane default
    gtl_type
  end
  private :get_view_calculate_gtl_type

  def get_view_process_search_text(view)
    # Check for new search by name text entered
    if params[:search] &&
       # Disabled search for Storage CIs until backend is fixed to handle evm_display_name field
       !["CimBaseStorageExtent","OntapStorageSystem","OntapLogicalDisk","OntapStorageVolume","OntapFileShare","SniaLocalFileSystem"].include?(view.db)
      @search_text = params[:search][:text].blank? ? nil : params[:search][:text].strip
    elsif params[:search_text] && @explorer
      @search_text = params[:search_text].blank? ? nil : params[:search_text].strip
    end

    # Build sub_filter where clause from search text"OntapLogicalDisk
    if @search_text && (
        (!@parent && @lastaction == "show_list" && !session[:menu_click]) ||
        (@explorer && !session[:menu_click]) ||
        (@layout == "miq_policy")) # Added to handle search text from list views in control explorer

      stxt = @search_text.gsub("_", "`_")                 # Escape underscores
      stxt.gsub!("%", "`%")                               #   and percents

      stxt = if stxt.starts_with?("*") && stxt.ends_with?("*")   # Replace beginning/ending * chars with % for SQL
               "%#{stxt[1..-2]}%"
             elsif stxt.starts_with?("*")
               "%#{stxt[1..-1]}"
             elsif stxt.ends_with?("*")
               "#{stxt[0..-2]}%"
             else
               "%#{stxt}%"
             end

      if MiqServer.my_server.get_config("vmdb").config.fetch_path(:server, :case_sensitive_name_search)
        sub_filter = ["#{view.db_class.table_name}.#{view.col_order.first} like ? escape '`'", stxt]
      else
        #don't apply sub_filter when viewing sub-list view of a CI
        sub_filter = ["lower(#{view.db_class.table_name}.#{view.col_order.first}) like ? escape '`'", stxt.downcase] if !@display
      end
    end
    sub_filter
  end
  private :get_view_process_search_text

  def perpage_key(dbname)
    %w(job miqtask).include?(dbname) ? :job_task : PERPAGE_TYPES[@gtl_type]
  end
  private :perpage_key

  # Create view and paginator for a DB records with/without tags
  def get_view(db, options = {})
    db     = db.to_s
    dbname = options[:dbname] || db.split("::").last.downcase # Get db name as text
    db_sym = dbname.to_sym                                    # Get db name as symbol
    refresh_view = false

    # Determine if the view should be refreshed or use the existing view
    unless session[:view] &&                          # A view exists and
            session[:view].db.downcase == dbname &&   # the DB matches and
            params[:refresh] != "y" &&                # refresh not being forced and
            (
              params[:ppsetting] || params[:page] ||  # changed paging or
              params[:type]                           # gtl type
            )
      refresh_view = true
      session[:menu_click] = params[:menu_click]      # Creating a new view, remember if came from a menu_click
      session[:bc]         = params[:bc]              # Remember incoming breadcrumb as well
    end

    # Build the advanced search @edit hash
    if (@explorer && !@in_a_form && !["adv_search_clear", "tree_select"].include?(action_name)) ||
       (action_name == "show_list" && !session[:menu_click])
      adv_search_build(db.split("::").last)
    end
    if @edit && !@edit[:selected] &&                  # Load default search if search @edit hash exists
       @settings.fetch_path(:default_search, db.to_sym) # and item in listnav not selected
      load_default_search(@settings[:default_search][db.to_sym])
    end

    parent      = options[:parent] || nil             # Get passed in parent object
    @parent     = parent if parent != nil             # Save the parent object for the views to use
    association = options[:association] || nil        # Get passed in association (i.e. "users")
    view_suffix = options[:view_suffix] || nil        # Get passed in view_suffix (i.e. "VmReconfigureRequest")

    # Build sorting keys - Use association name, if available, else dbname
    # need to add check for miqreportresult, need to use different sort in savedreports/report tree for saved reports list
    sort_prefix = association || (dbname == "miqreportresult" && x_active_tree ? x_active_tree.to_s : dbname)
    sortcol_sym = "#{sort_prefix}_sortcol".to_sym
    sortdir_sym = "#{sort_prefix}_sortdir".to_sym

    # Set up the list view type (grid/tile/list)
    @settings[:views][db_sym] = params[:type] if params[:type]  # Change the list view type, if it's sent in

    @gtl_type = get_view_calculate_gtl_type(options[:gtl_dbname] || db_sym)

    # Get the view for this db or use the existing one in the session
    view = refresh_view ? get_db_view(db.split("::").last, :association => association, :view_suffix => view_suffix) : session[:view]

    # Check for changed settings in params
    if params[:ppsetting]                             # User selected new per page value
      @settings[:perpage][perpage_key(dbname)] = params[:ppsetting].to_i
    elsif params[:sortby]                             # New sort order (by = col click, choice = pull down)
      params[:sortby]      = params[:sortby].to_i - 1
      params[:sort_choice] = view.headers[params[:sortby]]
    elsif params[:sort_choice]                        # If user chose new sortcol, set sortby parm
      params[:sortby]      = view.headers.index(params[:sort_choice])
    end

    # Get the current sort info, else get defaults from the view
    @sortcol = if session[sortcol_sym].nil?
                 view.sortby.nil? ? view.col_order.index(view.col_order.first) : view.col_order.index(view.sortby.first)
               else
                 session[sortcol_sym].to_i
               end
    @sortdir = session[sortdir_sym] || (view.order == "Descending" ? "DESC" : "ASC")
    # Set/reset the sortby column and order
    get_sort_col                                  # set the sort column and direction
    session[sortcol_sym] = @sortcol               # Save the new sort values
    session[sortdir_sym] = @sortdir
    view.sortby = [view.col_order[@sortcol]]      # Set sortby array in the view
    view.order = @sortdir.downcase == "desc" ? "Descending" : "Ascending" # Normalize sort order

    @items_per_page = controller_name.downcase == "miq_policy" ? ONE_MILLION : get_view_pages_perpage(dbname)
    @items_per_page = ONE_MILLION if 'vm' == db_sym.to_s && controller_name == 'service'

    @current_page = options[:page] || (params[:page].nil? ? 1 : params[:page].to_i)

    view.conditions = options[:conditions] # Get passed in conditions (i.e. tasks date filters)

    # Save the paged_view_search_options for download buttons to use later
    session[:paged_view_search_options] = {
      :parent              => parent ? minify_ar_object(parent) : nil, # Make a copy of parent object (to avoid saving related objects)
      :parent_method       => options[:parent_method],
      :targets_hash        => true,
      :association         => association,
      :filter              => get_view_filter(options),
      :sub_filter          => get_view_process_search_text(view),
      :page                => options[:all_pages] ? 1 : @current_page,
      :per_page            => options[:all_pages] ? ONE_MILLION : @items_per_page,
      :where_clause        => get_view_where_clause(options),
      :named_scope         => options[:named_scope],
      :display_filter_hash => options[:display_filter_hash],
      :userid              => session[:userid]
    }
    # Call paged_view_search to fetch records and build the view.table and additional attrs
    view.table, attrs = view.paged_view_search(session[:paged_view_search_options])

    # adding filters/conditions for download reports
    view.user_categories = attrs[:user_filters]["managed"] if attrs && attrs[:user_filters] && attrs[:user_filters]["managed"]

    view.extras[:total_count] = attrs[:total_count]  if attrs[:total_count]
    view.extras[:auth_count]  = attrs[:auth_count]   if attrs[:auth_count]
    @targets_hash             = attrs[:targets_hash] if attrs[:targets_hash]

    # Set up the grid variables for list view, with exception models below
    if !%w(Job MiqProvision MiqReportResult MiqTask).include?(view.db) &&
      !view.db.ends_with?("Build") && !@force_no_grid_xml && (@gtl_type == "list" || @force_grid_xml)
      @grid_xml = view_to_xml(view, 0, -1, :association => association)
    end

    [view, get_view_pages(dbname, view)]
  end

  def get_view_where_clause(options)
    # If doing charts, limit the records to ones showing in the chart
    if session[:menu_click] && session[:sandboxes][params[:sb_controller]][:chart_reports]
      menu_click_parts = session[:menu_click].split('_')
      menu_click_last  = menu_click_parts.last.split('-')

      chart_reports = session[:sandboxes][params[:sb_controller]][:chart_reports]
      legend_idx    = menu_click_last.first.to_i - 1
      data_idx      = menu_click_last[-2].to_i - 1
      chart_idx     = menu_click_last.last.to_i
      _, model, typ = menu_click_parts.first.split('-')
      report        = chart_reports.is_a?(Array) ? chart_reports[chart_idx] : chart_reports
      data_row      = report.table.data[data_idx]

      if typ == "bytag"
        ["\"#{model.downcase.pluralize}\".id IN (?)",
          data_row["assoc_ids_#{report.extras[:group_by_tags][legend_idx]}"][model.downcase.to_sym][:on]]
      else
        ["\"#{model.downcase.pluralize}\".id IN (?)",
          data_row["assoc_ids"][model.downcase.to_sym][typ.to_sym]]
      end
    elsif options[:where_clause]
      options[:where_clause]
    end
  end
  private :get_view_where_clause

  def get_view_filter(options)
    # Get the advanced search filter
    filter = nil
    if @edit && @edit[:adv_search_applied] && !session[:menu_click]
      filter = MiqExpression.new(@edit[:adv_search_applied][:qs_exp] || @edit[:adv_search_applied][:exp])
    end

    # workaround to pass MiqExpression as a filter to paged_view_search for MiqRequest
    # show_list, can't be used with advanced search or other list view screens
    filter ||= options[:filter]
    filter
  end
  private :get_view_filter

  def get_view_pages_perpage(dbname)
    perpage = 10 # return a sane default
    return perpage unless @settings.key?(:perpage)

    key = perpage_key(dbname)
    perpage = @settings[:perpage][key] if key && @settings[:perpage].key?(key)

    perpage
  end
  private :get_view_pages_perpage

  # Create the pages hash and return with the view
  def get_view_pages(dbname, view)
    pages = {
      :perpage => get_view_pages_perpage(dbname),
      :current => params[:page].nil? ? 1 : params[:page].to_i,
      :items   => view.extras[:auth_count] || view.extras[:total_count]
    }
    pages[:total] = (pages[:items] + pages[:perpage] - 1) / pages[:perpage]
    pages
  end
  private :get_view_pages

  # Generate an include string to append to "include_hash =" and eval'd
  # This routine is called recursively (passes in the include hash)
  def make_include_string(include)
    rt_string = "{"                                                 # Add the :include prefix
    include.keys.each_with_index do |table,idx|                               # Go thru all of the tables in the include
      rt_string << "," if idx > 0                                             # Need a comma for second and higher tables
      rt_string << "'" + table << "'" << "=>{"                                # Add the :only prefix
      if include[table]["columns"] != nil                                     # If there are columns
        rt_string << ":only=>["                                               # Add the :only prefix
        rt_string << include[table]["columns"].dup.collect!{|col| "'" << col << "'"}.join(",")  # Get all the column name strings
        rt_string << "]"                                                      # Add final bracket for the cols array
      end
      if include[table]["include"] != nil
        rt_string << "," if include[table]["columns"] != nil
        rt_string << make_include_string(include[table]["include"])           # Check for an embedded include
      end
      rt_string << "}"                                                        # Add final bracket for the table hash
    end
    rt_string << "}"                                                          # Add final bracket for the include hash
  end

  def get_db_view(db, options={})
    view_yaml = view_yaml_filename(db, options)
    view      = MiqReport.new(get_db_view_yaml(view_yaml))
    view.db   = db if view_yaml.ends_with?("Vm__restricted.yaml")
    view.extras ||= {}                        # Always add in the extras hash
    view
  end

  def view_yaml_filename(db, options)
    suffix = options[:association] || options[:view_suffix]

    # Build the view file name
    if suffix
      viewfile = "#{VIEWS_FOLDER}/#{db}-#{suffix}.yaml"
      viewfilebyrole = "#{VIEWS_FOLDER}/#{db}-#{suffix}-#{session[:userrole]}.yaml"
    else
      viewfile = "#{VIEWS_FOLDER}/#{db}.yaml"
      viewfilebyrole = "#{VIEWS_FOLDER}/#{db}-#{session[:userrole]}.yaml"
    end

    # Special code to build the view file name for users of VM restricted roles
    if %w(TemplateCloud TemplateInfra VmCloud VmInfra VmOrTemplate).include?(db)
      role = User.current_user.miq_user_role
      if role && role.settings && role.settings.fetch_path(:restrictions, :vms)
        viewfilerestricted = "#{VIEWS_FOLDER}/Vm__restricted.yaml"
      end
    end

    if viewfilerestricted && File.exist?(viewfilerestricted)
      viewfilerestricted
    elsif File.exist?(viewfilebyrole)
      viewfilebyrole
    else
      viewfile
    end
  end

  def get_db_view_yaml(filename)
    @db_view_yaml ||= {}
    @db_view_yaml.delete(filename) if Rails.env.development?
    @db_view_yaml[filename] ||= begin
      YAML.load_file(filename)
    end
  end

  # RJS code to show tag box effects and replace the main list view area
  def replace_gtl_main_div(options={})
    action_url = options[:action_url] || @lastaction
    session[:adv_search_on] = false
    return if params[:action] == "button" && @lastaction == "show"
    render :update do |page|                        # Use RJS to update the display
#     page.visual_effect(:blind_up,"tag_box_div") if session[:applied_tags] != nil && @applied_tags == nil      # Hide div if removing all tags
#     page.replace_html("tag_box_div", :partial=>"layouts/tag_box")                                             # Replace the tag box contents
#     page.visual_effect(:blind_down, "tag_box_div")  if session[:applied_tags] == nil && @applied_tags != nil  # Show div if not shown already
      page.replace(:flash_msg_div, :partial=>"layouts/flash_msg")           # Replace the flash message
      page << "if (typeof miq_toolbars != 'undefined'){";                 # Need to make sure toolbars exist on the screen before resetting buttons
      page << "miqSetButtons(0,'center_tb');"                             # Reset the center toolbar
      page << "}";
      if ! (@layout == "dashboard" && ["show","change_tab","auth_error"].include?(@controller.action_name) ||
        %w(about all_tasks all_ui_tasks configuration diagnostics miq_ae_automate_button
           miq_ae_customization miq_ae_export miq_ae_logs miq_ae_tools miq_policy miq_policy_export
           miq_policy_logs miq_request_ae miq_request_configured_system miq_request_host
           miq_request_vm my_tasks my_ui_tasks report rss server_build).include?(@layout))
        page.replace(:listnav_div, :partial=>"layouts/listnav")               # Replace accordion, if list_nav_div is there
      end
      if @grid_xml                                  # Replacing a grid
        page << "xml = \"#{j_str(@grid_xml)}\";"            # Set the XML data
        page << "gtl_list_grid.clearAll(true);"     # Clear grid data, including headers
        page << "gtl_list_grid.parse(xml);"         # Reload grid from XML
        if @sortcol
          dir = @sortdir ? @sortdir[0..2] : "asc"
          page << "gtl_list_grid.setSortImgState(true, #{@sortcol + 2}, '#{dir}');"
        end
        page << "miqGridOnCheck(null, null, null);" # Reset the center buttons
        page.replace("pc_div_1", :partial=>'/layouts/pagingcontrols', :locals=>{:pages=>@pages, :action_url=>action_url, :db=>@view.db, :headers=>@view.headers})
        page.replace("pc_div_2", :partial=>'/layouts/pagingcontrols', :locals=>{:pages=>@pages, :action_url=>action_url})
      else                                          # No grid, replace the gtl div
        page.replace_html("main_div", :partial=>"layouts/gtl")                                                  # Replace the main div area contents
        page << "$('#adv_div').slideUp(0.3);" if params[:entry]
      end
    end
  end

  # Build the audit object when a record is created, including all of the new fields
  #   params - rec = db record, eh = edit hash containing new values
  def build_created_audit(rec, eh)
    { :event        => "#{rec.class.to_s.downcase}_record_add",
      :target_id    => rec.id,
      :target_class => rec.class.base_class.name,
      :userid       => session[:userid],
      :message      => build_audit_msg(eh[:new], nil,
                                  "[#{eh[:new][:name]}] Record created")
    }
  end

  # Build the audit object when a record is saved, including all of the changed fields
  #   params - rec = db record, eh = edit hash containing current and new values
  def build_saved_audit(rec, eh)
    { :event        => "#{rec.class.to_s.downcase}_record_update",
      :target_id    => rec.id,
      :target_class => rec.class.base_class.name,
      :userid       => session[:userid],
      :message      => build_audit_msg(eh[:new], eh[:current],
        "[#{eh[:new][:name] ? eh[:new][:name] : rec[:name]}] Record updated")
    }
  end

  def prov_redirect(typ=nil)
    assert_privileges(params[:pressed])
    if typ  # we need to do this check before doing anything to prevent
            # history being updated
      vm_ids = find_checked_items.map(&:to_i).uniq
      if !typ.eql?("clone") && VmOrTemplate.includes_template?(vm_ids)
        render_flash_not_applicable_to_model(typ)
        return
      end
      if typ.eql?("clone") && vm_ids.present? && !VmOrTemplate.cloneable?(vm_ids)
        render_flash_not_applicable_to_model(typ)
        return
      end
      if typ.eql?("publish") && VmOrTemplate.where(:id => vm_ids, :type => %w(VmMicrosoft VmRedhat)).exists?
        render_flash_not_applicable_to_model(typ)
        return
      end
    end

    @in_a_form = true
    @redirect_controller = "miq_request"
    if request.parameters[:pressed].starts_with?("host_")       # need host id for host prov
      @org_controller = "host"                                  # request originated from controller
      @refresh_partial = "prov_edit"
      if params[:id]
        @prov_id = params[:id]
      else
        @prov_id = find_checked_items.map(&:to_i).uniq
        res = Host.ready_for_provisioning?(@prov_id)
        if res != true
          res.each do |field,msg|
            add_flash("#{field.to_s.capitalize} #{msg}", :error)
          end
          @redirect_controller = "host"
          @refresh_partial = "show_list"
        end
      end
    else
      @org_controller = "vm"                                      #request originated from controller
      @refresh_partial = "pre_prov"
    end
    if typ
      vms = find_checked_items
      case typ
      when "clone"
        @prov_id = !vms.empty? ? vms[0] : params[:id]
        @prov_type = "clone_to_vm"
      when "migrate"
        @prov_id = !vms.empty? ? vms : [params[:id]]
        @prov_type = "migrate"
      when "publish"
        @prov_id = !vms.empty? ? vms[0] : params[:id]
        @prov_type = "clone_to_template"
      end
      @_params[:prov_id] = @prov_id
      @_params[:prov_type] = @prov_type
    end

    if @explorer
      @_params[:org_controller] = "vm"
      if typ
        prov_edit
      else
        vm_pre_prov
      end
    end
  end
  alias image_miq_request_new prov_redirect
  alias instance_miq_request_new prov_redirect
  alias vm_miq_request_new prov_redirect

  def vm_clone
    prov_redirect("clone")
  end
  alias image_clone vm_clone
  alias instance_clone vm_clone
  alias miq_template_clone vm_clone

  def vm_migrate
    prov_redirect("migrate")
  end
  alias miq_template_migrate vm_migrate

  def vm_publish
    prov_redirect("publish")
  end

  def get_global_session_data
    # Set the current userid in the User class for this thread for models to use
    User.current_userid = session[:userid]

    # Get/init sandbox (@sb) per controller in the session object
    session[:sandboxes] ||= HashWithIndifferentAccess.new
    @sb = session[:sandboxes][controller_name].blank? ? Hash.new : copy_hash(session[:sandboxes][controller_name])

    # Init view sandbox variables
    @current_page = @sb[:current_page]                                              # current page number
    @search_text = @sb[:search_text]                                                # search text
    @detail_sortcol = @sb[:detail_sortcol] == nil ? 0 : @sb[:detail_sortcol].to_i   # sort column for detail lists
    @detail_sortdir = @sb[:detail_sortdir] == nil ? "ASC" : @sb[:detail_sortdir]    # sort column for detail lists

    # Get performance hash, if it is in the sandbox for the running controller
    @perf_options = @sb[:perf_options] ? copy_hash(@sb[:perf_options]) : Hash.new

    # Set window width/height for views to use
    @winW = session[:winW] ? session[:winW].to_i : 1330
    @winH = session[:winH] ? session[:winH].to_i : 805

    # Set @edit key default for the expression editor to use
    @expkey = session[:expkey] ? session[:expkey] : :expression

    # Get server hash, if it is in the session for supported controllers
    @server_options = session[:server_options] if ["configuration","support"].include?(controller_name)

    # Get timelines hash, if it is in the session for the running controller
    @tl_options = session["#{controller_name}_tl".to_sym]

    session[:adv_search_on] = false if action_name[0..3] != "adv_" # Turn off advanced search flag if not an adv search action
    session[:host_url] = request.env["HTTP_HOST"]   unless request.env["HTTP_HOST"] == nil
    session[:tab_url] ||= Hash.new

    unless request.xml_http_request?  # Don't capture ajax URLs
      # Capture current top tab bar URLs as they come in
      if action_name == "explorer" # For explorers, don't capture any parms, nil out id
        inbound_url = {
          :controller => controller_name,
          :action     => action_name,
          :id         => nil }
      else
        inbound_url = {
          :controller  => controller_name,
          :action      => action_name,
          :id          => request.parameters["id"],
          :display     => request.parameters["display"],
          :role        => request.parameters["role"],
          :config_tab  => request.parameters["config_tab"],
          :support_tab => request.parameters["support_tab"],
          :rpt_group   => request.parameters["rpt_group"],
          :rpt_index   => request.parameters["rpt_index"],
          :typ         => request.parameters["typ"]
        }
      end

      # Customize URLs for controllers that don't use breadcrumbs
      case controller_name
      when "dashboard", "report", "alert","chargeback"
        session[:tab_url][:vi] = inbound_url if ["show", "show_list", "timeline", "jobs","ui_jobs","usage","chargeback","explorer"].include?(action_name)
      when "support"
        session[:tab_url][:set] = inbound_url if ["index"].include?(action_name)
      when "configuration", "miq_task", "ops"
        session[:tab_url][:set] = inbound_url if ["explorer","index"].include?(action_name)
      when "miq_ae_tools", "miq_ae_class", "miq_ae_customization"
        session[:tab_url][:aut] = inbound_url if ["explorer","resolve","index","explorer","log","import_export","automate_button"].include?(action_name)
      when "miq_policy" # Only grab controller and action for policy URLs
        session[:tab_url][:con] = {:controller => controller_name, :action => action_name} if ["explorer","rsop","export","log"].include?(action_name)
      when "miq_capacity"
        session[:tab_url][:opt] = inbound_url if ["utilization","planning","bottlenecks","waste"].include?(action_name)
      when "catalog", "vm", "vm_or_template", "miq_template", "service"
        session[:tab_url][:svc] = inbound_url if ["show", "show_list", "explorer"].include?(action_name)
      when "availability_zone", "ems_cloud", "flavor", "security_group", "vm_cloud", "orchestration_stack"
        session[:tab_url][:clo] = inbound_url if ["show", "show_list", "explorer"].include?(action_name)
      when "ems_cluster", "ems_infra", "host", "pxe", "repository", "resource_pool", "storage", "vm_infra"
        session[:tab_url][:inf] = inbound_url if ["show", "show_list", "explorer"].include?(action_name)
      when "container", "container_group", "container_node", "container_service", "ems_container",
           "container_route", "container_project", "container_replicator"
        session[:tab_url][:cnt] = inbound_url if %w(explorer show show_list).include?(action_name)
      when "miq_request"
        session[:tab_url][:svc] = inbound_url if ["index"].include?(action_name) && request.parameters["typ"] == "vm"
        session[:tab_url][:inf] = inbound_url if ["index"].include?(action_name) && request.parameters["typ"] == "host"
      when "provider_foreman"
        session[:tab_url][:inf] = inbound_url if %w(show explorer).include?(action_name)
      end
    end

    # Get all of the global variables used by most of the controllers
    @pp_choices = PPCHOICES
    @panels = session[:panels] == nil ? Hash.new : session[:panels]
    @breadcrumbs = session[:breadcrumbs] == nil ? Array.new : session[:breadcrumbs]
    @panels["icon"] = true if @panels["icon"] == nil                # Default icon panels to be open
    @panels["tag_filters"] = true if @panels["tag_filters"] == nil  # Default tag filters panels to be open
    @panels["sections"] = true if @panels["sections"] == nil        # Default sections(compare) panel to be open

#   if params[:flash_msgs] && session[:flash_msgs]    # Incoming flash msg array is present
    if session[:flash_msgs]       # Incoming flash msg array is present
      @flash_array = session[:flash_msgs].dup
      session[:flash_msgs] = nil
    elsif params[:flash_msg]      # Add incoming flash msg, with/without error flag
      #params coming in from redirect are strings and being sent up even when value is false
      if params[:flash_error] == "true"
        add_flash(params[:flash_msg], :error)
      elsif params[:flash_warning]
        add_flash(params[:flash_msg], :warning)
      else
        add_flash(params[:flash_msg])
      end
    end

    # Set version info, if it doesn't exist
    if session[:vmdb] == nil
      session[:vmdb] = Hash.new
      session[:vmdb][:version] = Vmdb::Appliance.VERSION
      session[:vmdb][:build]   = Vmdb::Appliance.BUILD_NUMBER
    end

    # Get customer name
    session[:customer_name] = get_vmdb_config[:server][:company] if session[:customer_name] == nil
    session[:vmdb_name] = get_vmdb_config[:server][:name] if session[:vmdb_name] == nil
    session[:custom_logo] = get_vmdb_config[:server][:custom_logo] if session[:custom_logo] == nil

    # Get settings hash from the session
    @settings = session[:settings]
    @css = session[:css]
    params[:ppsetting] = params[:perpage_setting1] || params[:perpage_setting2] || params[:perpage_setting3] if params[:perpage_setting1] || params[:perpage_setting2] || params[:perpage_setting3]
    # Get edit hash from the session
    # Commented following line in sprint 39. . . controllers should load @edit if they need it and we will
    # automatically save it in the session if it's present when the transaction ends
#   @edit = session[:edit] ? session[:edit] : nil
    @temp = Hash.new    # to hold tree/xml data that was stored in session previously
    return true     # If we don't return true, the entire session stops cold
  end

  # Check for session threshold limits and write log messages if exceeded
  def get_data_size(data, indent = 0)
    begin
      #TODO: (FB 9144) Determine how the session store handles singleton object so it does not throw errors.
      data_size = Marshal.dump(data).size
    rescue => err
      data_size = 0
      $log.warn("MIQ(#{controller_name}_controller-#{action_name}): get_data_size error: <#{err}>\n#{err.backtrace.join("\n")}")
    end

    if indent.zero?
      if Rails.env.development?
        puts "Session:\t #{data.class.name} of Size #{data_size}, Elements #{data.size}\n================================="
      end
      return if data_size < SESSION_LOG_THRESHOLD
      msg = "Session object size of #{number_to_human_size(data_size)} exceeds threshold of #{number_to_human_size(SESSION_LOG_THRESHOLD)}"
      if Rails.env.development?
        puts "***** MIQ(#{controller_name}_controller-#{action_name}): #{msg}"
      end
      $log.warn("MIQ(#{controller_name}_controller-#{action_name}): " + msg)
    end

    if data.kind_of?(Hash) && data_size > SESSION_ELEMENT_THRESHOLD
      data.keys.sort_by(&:to_s).each do |k|
        value = data[k]
        log_data_size(k, value, indent)
        get_data_size(value, indent + 1)  if value.kind_of?(Hash) || value.kind_of?(Array)
      end
    elsif data.kind_of?(Array) && data_size > SESSION_ELEMENT_THRESHOLD
      data.each_index do |k|
        value = data[k]
        log_data_size(k, value, indent)
        get_data_size(value, indent + 1)  if value.kind_of?(Hash) || value.kind_of?(Array)
      end
    end
  end

  # Dump the entire session contents to the evm.log
  def dump_session_data(data, indent = 0)
    begin
      #TODO: (FB 9144) Determine how the session store handles singleton object so it does not throw errors.
      data_size = Marshal.dump(data).size
    rescue => err
      data_size = 0
      $log.warn("MIQ(#{controller_name}_controller-#{action_name}): dump_session error: <#{err}>\n#{err.backtrace.join("\n")}")
    end

    if indent.zero?
      $log.warn("MIQ(#{controller_name}_controller-#{action_name}): ===============BEGIN SESSION DUMMP===============")
    end

    if data.kind_of?(Hash)
      data.keys.sort_by(&:to_s).each do |k|
        value = data[k]
        log_data_size(k, value, indent)
        dump_session_data(value, indent + 1) if value.kind_of?(Hash) || value.kind_of?(Array)
      end
    elsif data.kind_of?(Array)
      data.each_index do |k|
        value = data[k]
        log_data_size(k, value, indent)
        dump_session_data(value, indent + 1)  if value.kind_of?(Hash) || value.kind_of?(Array)
      end
    end

    if indent.zero?
      $log.warn("MIQ(#{controller_name}_controller-#{action_name}): ===============END SESSION DUMMP===============")
    end
  end

  # Log sizes and values from get_data_size and dump_session_data methods
  def log_data_size(el, value, indent)
    indentation = "  " * indent
    if value.kind_of?(Hash) || value.kind_of?(Array) || value.kind_of?(ActiveRecord::Base) ||
        !value.respond_to?("size")
      val_size = Marshal.dump(value).size
    else
      val_size = value.size
    end
    line = "#{indentation}#{el} <#{value.class.name}> Size #{val_size}"
    line << " Elements #{value.size}"  if value.kind_of?(Hash) || value.kind_of?(Array)
    line << " ActiveRecord Object!!" if value.kind_of?(ActiveRecord::Base)
    line << " Value #{value.inspect[0...2000]}" unless value.kind_of?(Hash) || value.kind_of?(Array) || value.kind_of?(ActiveRecord::Base)
    $log.warn("MIQ(#{controller_name}_controller-#{action_name}): " + line)
  end

  def set_global_session_data
    Picture.sync_to_disk(@pictures_to_sync) if @pictures_to_sync
    @sb ||= Hash.new
    # Set all of the global variables used by most of the controllers
    session[:layout] = @layout
    session[:panels] = @panels
    session[:breadcrumbs] = @breadcrumbs
    session[:applied_tags] = @applied_tags  # Search box applied tags for the current list view
    session[:miq_compare] = @compare.nil? ? (@keep_compare ? session[:miq_compare] : nil) : Marshal.dump(@compare)
    session[:miq_compressed] = @compressed if @compressed != nil
    session[:miq_exists_mode] = @exists_mode if @exists_mode != nil
    session[:last_trans_time] = Time.now

    # Save @edit key for the expression editor to use
    session[:expkey] = @expkey

    # Set server hash, if @server_options is present
    session[:server_options] = @server_options

    # Set timelines hash, if it is in the session for the running controller
    session["#{controller_name}_tl".to_sym] = @tl_options if @tl_options != nil

    # Capture breadcrumbs by main tab
    session[:tab_bc] ||= Hash.new
    unless session[:menu_click]   # Don't save breadcrumbs after a chart menu click
      case controller_name

      # These controllers don't use breadcrumbs, see above get method to store URL
      when "dashboard","report","support","alert","jobs","ui_jobs","miq_ae_tools","miq_policy","miq_action","miq_capacity","chargeback"

      when "service"
        session[:tab_bc][:vs] = @breadcrumbs.dup if ["show", "show_list"].include?(action_name)
      when "ontap_storage_system","ontap_logical_disk","cim_base_storage_extent","ontap_storage_volume","ontap_file_share","snia_local_file_system","storage_manager"
        session[:tab_bc][:sto] = @breadcrumbs.dup if ["show", "show_list", "index"].include?(action_name)
      when "ems_cloud", "availability_zone", "flavor"
        session[:tab_bc][:clo] = @breadcrumbs.dup if ["show", "show_list"].include?(action_name)
      when "ems_infra", "datacenter", "ems_cluster", "resource_pool", "storage", "repository", "pxe_server"
        session[:tab_bc][:inf] = @breadcrumbs.dup if ["show", "show_list"].include?(action_name)
      when "host"
        session[:tab_bc][:inf] = @breadcrumbs.dup if ["show", "show_list", "log_viewer"].include?(action_name)
      when "miq_request"
        if @layout == "miq_request_vm"
          session[:tab_bc][:vms] = @breadcrumbs.dup if ["show", "show_list"].include?(action_name)
        else
          session[:tab_bc][:inf] = @breadcrumbs.dup if ["show", "show_list"].include?(action_name)
        end
      when "vm"
        session[:tab_bc][:vms] = @breadcrumbs.dup if %w{
                                                          show
                                                          show_list
                                                          usage
                                                          guest_applications
                                                          registry_items
                                                          vmtree
                                                          users
                                                          groups
                                                          linuxinitprocesses
                                                          win32services
                                                          kerneldrivers
                                                          filesystemdrivers
                                                          }.include?(action_name)
      end
    end

    # Save settings hash in the session
    session[:settings] = @settings
    session[:css] = @css

    # Save/reset session variables based on @variable presence
    session[:imports] = @sb[:imports] ? @sb[:imports] : nil # Imported file data from 2 stage import

    # Save @edit and @view in session, if present
    if @lastaction == "show_list"                           # If show_list was the last screen presented or tree is being autoloaded save @edit
      @edit ||= session[:edit]                              #   Remember the previous @edit
      @view ||= session[:view]                              #   Remember the previous @view
    end

    session[:edit] = @edit ? @edit : nil                    # Set or clear session edit hash

    session[:view] = @view ? @view : nil                    # Set or clear view in session hash
    unless params[:controller] == "miq_task"                # Proxy needs data for delete all
      session[:view].table = nil if session[:view]          # Don't need to carry table data around
    end

    # Put performance hash, if it exists, into the sandbox for the running controller
    @sb[:perf_options] = copy_hash(@perf_options) if @perf_options

    # Save @assign hash in sandbox
    @sb[:assign] = @assign ? copy_hash(@assign) : nil

    # Save view sandbox variables
    @sb[:current_page] = @current_page
    @sb[:search_text] = @search_text
    @sb[:detail_sortcol] = @detail_sortcol
    @sb[:detail_sortdir] = @detail_sortdir

    @sb[:tree_hosts_hash] = nil if (!%w{ems_folders descendant_vms}.include?(params[:display]) &&
        !%w{treesize tree_autoload_dynatree tree_autoload_quads}.include?(params[:action]))
    @sb[:tree_vms_hash] = nil if (!%w{ems_folders descendant_vms}.include?(params[:display]) &&
        !%w{treesize tree_autoload_dynatree tree_autoload_quads}.include?(params[:action]))

    # Set/clear sandbox (@sb) per controller in the session object
    session[:sandboxes] ||= HashWithIndifferentAccess.new
    session[:sandboxes][controller_name] = @sb.blank? ? nil : copy_hash(@sb)

    # Clear out pi_xml and pi from sandbox if not in policy controller or no longer need to hang on to policy import data, clearing it out incase user switched screen before importing data
    if session[:sandboxes][:miq_policy] && (request.parameters[:controller] != "miq_policy" || (request.parameters[:controller] == "miq_policy" && !params[:commit] && !params[:button]))
      session[:sandboxes][:miq_policy][:pi_xml] = nil
      session[:sandboxes][:miq_policy][:pi]     = nil
    end

    # Clearing out session objects that are no longer needed
    session[:myco_tree] = session[:hac_tree] = session[:vat_tree] = nil if controller_name != "ops"
    session[:dc_tree] = nil if (!["ems_folders","descendant_vms"].include?(params[:display]) && !["treesize","tree_autoload"].include?(params[:action]))
    session[:ch_tree] = nil if !["compliance_history"].include?(params[:display]) && params[:action] != "treesize" && params[:action] != "squash_toggle"
    session[:vm_tree] = nil if !["vmtree_info"].include?(params[:display]) && params[:action] != "treesize"
    session[:policy_tree] = nil if params[:action] != "policies" && params[:pressed] != "vm_protect" && params[:action] != "treesize"
    session[:resolve] = session[:resolve_object] = nil if !["catalog","miq_ae_customization","miq_ae_tools"].include?(request.parameters[:controller])
    session[:report_menu] = session[:report_folders] = session[:menu_roles_tree] = nil if controller_name != "report"
    session[:rsop_tree] = nil if controller_name != "miq_policy"
    if session.class != Hash
      session_hash = session.respond_to?(:to_hash) ? session.to_hash : session.data
      get_data_size(session_hash)
      dump_session_data(session_hash) if get_vmdb_config[:product][:dump_session]
    end
  end

  # Following 3 methods moved here to ensure they are loaded at the right time and will be available to all controllers
  def find_by_id_filtered(db, id)
    raise "Invalid input" unless is_integer?(id)

    userid     = session[:userid]

    unless db.where(:id => from_cid(id)).exists?
      msg = _("Selected %s no longer exists") %  ui_lookup(:model => db.to_s)
      raise msg
    end

    msg = "User '#{userid}' is not authorized to access '#{ui_lookup(:model=>db.to_s)}' record id '#{id}'"
    conditions = ["#{db.table_name}.id = ?", id]
    result = Rbac.search(:class => db, :conditions => conditions, :userid => userid, :results_format => :objects).first.first
    raise msg if result.nil?

    result
  end

  def find_filtered(db, count, options={})
    user     = User.find_by_userid(session[:userid])
    mfilters = user ? user.get_managed_filters   : []
    bfilters = user ? user.get_belongsto_filters : []

    if db.respond_to?(:find_filtered) && !mfilters.empty?
      result = db.find_tags_by_grouping(mfilters, :conditions => options[:conditions], :ns=>"*")
    else
      result = db.find(count, options)
    end

    result = MiqFilter.apply_belongsto_filters(result, bfilters) if db.respond_to?(:find_filtered) &&  result

    result
  end

  def ruport_ize_filtered(report, options = {})
    userid = session[:userid]
    user = User.find_by_userid(userid)
    options[:tag_filters] = user ? user.get_filters   : []
    report.ruport_ize!(options)
  end

  VISIBILITY_TYPES = {'role' => 'role', 'group' => 'group', 'all' => 'all'}

  def visibility_box_edit
    typ_changed = params[:visibility_typ].present?
    @edit[:new][:visibility_typ] = VISIBILITY_TYPES[params[:visibility_typ]] if typ_changed

    visibility_typ = @edit[:new][:visibility_typ]
    if %w(role group).include?(visibility_typ)
      plural = visibility_typ.pluralize
      key    = plural.to_sym
      prefix = "#{plural}_"

      @edit[:new][key] = [] if typ_changed
      params.each do |var, value|
        if var.starts_with?(prefix)
          name = var.split(prefix).last
          if value == "1"
            @edit[:new][key] |= [name]    # union
          elsif value.downcase == "null"
            @edit[:new][key].delete(name)
          end
        end
      end
    else
      @edit[:new][:roles] ||= []
      @edit[:new][:roles] |= ["_ALL_"]
    end
  end

  # Find a record by model name and ID, set flash errors for not found/not authorized
  def find_by_model_and_id_check_rbac(model, id, resource_name = nil)
    rec = model.constantize.find_by_id(id)
    if rec
      begin
        authrec = find_by_id_filtered(model.constantize, id)
      rescue ActiveRecord::RecordNotFound
      rescue StandardError => @bang
      end
    end
    if rec.nil?
      record_name = resource_name ? "#{ui_lookup(:model=>model)} '#{resource_name}'" : "The selected record"
      add_flash(_("%s no longer exists in the database") % record_name,
                :error)
    elsif authrec.nil?
      add_flash(_("You are not authorized to view %s") % "#{ui_lookup(:model=>rec.class.base_model.to_s)} '#{resource_name}'",
                :error)
    end
    return rec
  end

  def get_record_display_name(record)
    return record.label                      if record.respond_to?("label")
    return record.ext_management_system.name if record.respond_to?("ems_id")
    return record.description                if record.respond_to?("description") && !record.description.nil?
    return record.title                      if record.respond_to?("title")
    return record.name                       if record.respond_to?("name")
    return "<Record ID #{record.id}>"
  end

  def identify_tl_or_perf_record
    identify_record(params[:id], controller_to_model)
  end

  def assert_privileges(feature)
    raise MiqException::RbacPrivilegeException,
          _("The user is not authorized for this task or item.") unless role_allows(:feature => feature)
  end

  def previous_breadcrumb_url
    @breadcrumbs[-2][:url]
  end
  helper_method(:previous_breadcrumb_url)

  def controller_for_common_methods
    case controller_name
    when "vm_infra", "vm_or_template", "vm_cloud"
      "vm"
    else
      controller_name
    end
  end

  def list_row_id(row)
    to_cid(row['id'])
  end

  def list_row_image(image_path, image, model_image, _itemname)
    image ? image : "#{image_path}#{model_image}.png"
  end

  def render_flash_not_applicable_to_model(type)
    add_flash(_("%{task} does not apply to selected %{model}") % {:model => ui_lookup(:table => "miq_template"), :task  => type.capitalize}, :error)
    render_flash { |page| page << '$(\'#main_div\').scrollTop();' }
  end

  def set_gettext_locale
    user_settings =  User.find_by_userid(session[:userid]).try(:settings)
    user_locale = user_settings[:display][:locale] if user_settings &&
                                                 user_settings.key?(:display) &&
                                                 user_settings[:display].key?(:locale)
    if user_locale == 'default' || user_locale.nil?
      unless MiqServer.my_server.nil?
        server_locale = MiqServer.my_server.get_config("vmdb").config.fetch_path(:server, :locale)
      end
      # user settings && server settings == 'default'
      # OR not defined
      # use HTTP_ACCEPT_LANGUAGE
      locale = if server_locale == "default" || server_locale.nil?
                 env['HTTP_ACCEPT_LANGUAGE']
               else
                 server_locale
               end
    else
      locale = user_locale
    end
    FastGettext.set_locale(locale)
  end

  def flip_sort_direction(direction)
    direction == "ASC" ? "DESC" : "ASC" # flip ascending/descending
  end
end
