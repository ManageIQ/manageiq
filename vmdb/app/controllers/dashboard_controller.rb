class DashboardController < ApplicationController
  @@items_per_page = 8

  before_filter :check_privileges, :except => [:csp_report, :window_sizes, :authenticate, :kerberos_authenticate,
                                               :logout, :login, :login_retry, :wait_for_task]
  before_filter :get_session_data, :except => [:csp_report, :window_sizes, :authenticate, :kerberos_authenticate]
  after_filter :cleanup_action,    :except => [:csp_report]
  after_filter :set_session_data,  :except => [:csp_report, :window_sizes]

  def index
    redirect_to :action => 'show'
  end

  skip_before_filter :set_csp_header, :only => :iframe # FIXME: only frame-src
  skip_before_filter :set_x_frame_options_header, :only => :iframe

  def iframe
    @layout = nil
    if params[:id].present?
      item = Menu::Manager.item(params[:id])
      @layout = item.id if item.present?
    elsif params[:sid].present?
      item = Menu::Manager.section(params[:sid])
      @layout = (item.items[0].id rescue nil)
    end
    @big_iframe = true
    render :locals => {:iframe_src => item.href}
  end

  def csp_report
    report = ActiveSupport::JSON.decode(request.body.read)
    $log.warn("security warning, CSP violation report follows: #{report.inspect}")
    render :nothing => true
  end

  # Accept window sizes from the client
  def window_sizes
    session[:winH] = params[:height] if params[:height]
    session[:winW] = params[:width] if params[:width]
    if params[:exp_left] && params[:exp_controller]
      # Set the left divider position in the controller's sandbox
      session[:sandboxes][params[:exp_controller]][:exp_left] = params[:exp_left]
    end
    render :nothing => true # No response required
  end

  VALID_TABS = lambda { |x| Hash[x.map(&:to_s).zip(x)] }[[
    :vi, :svc, :clo, :inf, :cnt, :con, :aut, :opt, :set,  # normal tabs
    :vs, :sto                                       # hidden tabs
  ]] # format is {"vi" => :vi, "svc" => :svc . . }

  EXPLORER_FEATURE_LINKS = {
    "catalog"             => "catalog",
    "containers"          => "containers",
    "pxe"                 => "pxe",
    "service"             => "service",
    "vm_cloud_explorer"   => "vm_cloud",
    "vm_explorer_accords" => "vm_or_template",
    "vm_infra_explorer"   => "vm_infra"
  }

  # A main tab was pressed
  def maintab
    tab = VALID_TABS[params[:tab]]

    unless tab # no tab name or invalid tab name was passed in
      render :action => "login"
      return
    end

    case tab
    when :vi, :svc, :clo, :inf, :cnt, :con, :aut, :opt, :set

      if session[:tab_url].key?(tab) # we remember url for this tab
        redirect_to(session[:tab_url][tab].merge(:only_path => true))
        return
      end

      tab_features = Menu::Manager.tab_features_by_id(tab)
      case tab
      when :vi
        tab_features.detect do |f|
          if f == "dashboard" && role_allows(:feature => "dashboard_view")
            redirect_to :action => "show"
          elsif role_allows(:feature => f)
            case f
            when "miq_report" then redirect_to(:controller => "report",    :action => "explorer")
            when "usage"      then redirect_to(:controller => "report",    :action => f)
            when "chargeback" then redirect_to(:controller => f,           :action => f)
            when "timeline"   then redirect_to(:controller => "dashboard", :action => f)
            when "rss"        then redirect_to(:controller => "alert",     :action => "show_list")
            end
          end
        end
      when :clo, :inf, :cnt, :svc
        tab_features.detect do |f|
          if EXPLORER_FEATURE_LINKS.include?(f) && role_allows(:feature => f, :any => true)
            redirect_to :controller => EXPLORER_FEATURE_LINKS[f], :action => "explorer"
          elsif role_allows(:feature => "#{f}_show_list")
            redirect_to :controller => f, :action => "show_list"
          end
        end
      when :con
        tab_features.detect do |f|
          if f == "control_explorer" && role_allows(:feature => "control_explorer_view")
            redirect_to :controller => "miq_policy", :action => "explorer"
          elsif role_allows(:feature => f)
            case f
            when "policy_simulation"    then redirect_to(:controller => "miq_policy", :action => "rsop")
            when "policy_import_export" then redirect_to(:controller => "miq_policy", :action => "export")
            when "policy_log"           then redirect_to(:controller => "miq_policy", :action => "log")
            end
          end
        end
      when :aut
        tab_features.detect { |f| role_allows(:feature => f) }.tap do |f|
          case f
          when "miq_ae_class_explorer"      then redirect_to(:controller => "miq_ae_class", :action => "explorer")
          when "miq_ae_class_simulation"    then redirect_to(:controller => "miq_ae_tools", :action => "resolve")
          when "miq_ae_class_custom_button" then redirect_to(:controller => "miq_ae_tools", :action => "custom_button")
          when "miq_ae_class_import_export" then redirect_to(:controller => "miq_ae_tools", :action => "import_export")
          when "miq_ae_class_log"           then redirect_to(:controller => "miq_ae_tools", :action => "log")
          end
        end
      when :opt
        tab_features.detect { |f| role_allows(:feature => f) }.tap do |f|
          redirect_to(:controller => "miq_capacity", :action => f) if f
        end
      when :set
        tab_features.detect do |f|
          if f == "my_settings" && role_allows(:feature => f, :any => true)
            redirect_to :controller => "configuration", :action => "index", :config_tab => "ui"
          elsif role_allows(:feature => f)
            case f
            when "tasks"        then redirect_to(:controller => "configuration", :action => "index")
            when "ops_explorer" then redirect_to(:controller => "ops",       :action => "explorer")
            when "about"        then redirect_to(:controller => "support",   :action => "index", :support_tab => "about")
            end
          end
        end
      end
    else
      tab_features = Menu::Manager.tab_features_by_id(tab)
      if Array(session[:tab_bc][tab]).empty? # no saved breadcrumbs for this tab
        case tab
        when :vs
          redirect_to :controller => "service"
        when :sto
          feature = tab_features.detect { |f| role_allows(:feature => "#{f}_show_list") }
          redirect_to(:controller => feature) if feature
        end
      else
        @breadcrumbs = session[:tab_bc][tab]
        redirect_to @breadcrumbs.last[:url]
      end
    end
    # FIXME: what if we get here?
  end

  # New tab was pressed
  def change_tab
    show
    render :action => "show"
  end

  def show
    @layout    = "dashboard"
    @dashboard = true

    g = MiqGroup.find_by_id(session[:group])
    db_order = if g.settings && g.settings[:dashboard_order]
                 g.settings[:dashboard_order]
               else
                 MiqWidgetSet.find_all_by_owner_id(session[:group]).sort_by { |a| a.name.downcase }.collect(&:id)
               end

    @tabs = []
    db_order.each_with_index do |d, i|
      db = MiqWidgetSet.find_by_id(d)
      # load first one on intial load, or load tab from params[:tab] changed,
      # or when coming back from another screen load active tab from sandbox
      if (!params[:tab] && !@sb[:active_db_id] && i == 0) || (params[:tab] && params[:tab] == db.id.to_s) ||
         (!params[:tab] && @sb[:active_db_id] && @sb[:active_db_id].to_s == db.id.to_s) ||
         (!db_order.include?(@sb[:active_db_id]) && !db_order.empty? && i == 0)
        @tabs.unshift([db.id.to_s, ""])
        @sb[:active_db]    = db.name
        @sb[:active_db_id] = db.id
      end
      @tabs.push([db.id.to_s, db.description])
      # check this only first time when user logs in comes to dashboard show

      next if @sb[:dashboards]
      # get user dashboard version
      ws = MiqWidgetSet.where_unique_on(db.name, session[:group], session[:userid]).first
      # update user's copy if group dashboard has been updated by admin
      if ws && ws.set_data && (!ws.set_data[:last_group_db_updated] ||
         (ws.set_data[:last_group_db_updated] && db.updated_on > ws.set_data[:last_group_db_updated]))
        # if group dashboard was locked earlier but now it is unlocked,
        # reset everything  OR if admin makes changes to a locked db do a reset on user's copies
        if (db.set_data[:locked] && !ws.set_data[:locked]) || (db.set_data[:locked] && ws.set_data[:locked])
          ws.set_data = db.set_data
          ws.set_data[:last_group_db_updated] = db.updated_on
          ws.save
        # if group dashboard was unloacked earlier but now it is locked,
        # only change locked flag of users dashboard version
        elsif !db.set_data[:locked] && ws.set_data[:locked]
          ws.set_data[:locked] = db.set_data[:locked]
          ws.set_data[:last_group_db_updated] = db.updated_on unless ws.set_data[:last_group_db_updated]
          ws.save
        end
      end
    end

    @sb[:dashboards] ||= {}
    ws = MiqWidgetSet.where_unique_on(@sb[:active_db], session[:group], session[:userid]).first

    # if all of user groups dashboards have been deleted and they are logged in, need to reset active_db_id
    if ws.nil?
      wset = MiqWidgetSet.find_by_id(@sb[:active_db_id])
      @sb[:active_db_id] = nil if wset.nil?
    end

    # Create default dashboard for this user, if not present
    ws = create_user_dashboard(@sb[:active_db_id]) if ws.nil?

    # Set tabs now if user's group didnt have any dashboards using default dashboard
    if db_order.empty?
      db = MiqWidgetSet.find_by_id(@sb[:active_db_id])
      @tabs.unshift([ws.id.to_s, ""])
      @tabs.push([ws.id.to_s, db.description])
    # User's group has dashboards, delete userid|default dashboard if it exists, dont need to keep that
    else
      db = MiqWidgetSet.where_unique_on("default", session[:group], session[:userid]).first
      db.destroy if db.present?
    end

    @sb[:dashboards][@sb[:active_db]] = ws.set_data
    @sb[:dashboards][@sb[:active_db]][:minimized] ||= [] # Init minimized widgets array

    # Build the available widgets for the pulldown
    col_widgets = @sb[:dashboards][@sb[:active_db]][:col1] +
                  @sb[:dashboards][@sb[:active_db]][:col2] +
                  @sb[:dashboards][@sb[:active_db]][:col3]

    # Build the XML to load the widget dropdown list dhtmlxtoolbar
    widget_list = ""
    prev_type   = nil
    @temp[:available_widgets] = []
    MiqWidget.available_for_user(session[:userid]).sort_by { |a| a.content_type + a.title.downcase }.each do |w|
      @temp[:available_widgets].push(w.id)  # Keep track of widgets available to this user
      if !col_widgets.include?(w.id) && w.enabled
        image, tip = case w.content_type
                     when "menu"   then ["menu",     "Add this Menu Widget"]
                     when "rss"    then ["rssfeed",  "Add this RSS Feed Widget"]
                     when "chart"  then ["piechart", "Add this Chart Widget"]
                     when "report" then ["report",   "Add this Report Widget"]
                     end
        if prev_type && prev_type != w.content_type
          widget_list << "<item id='#{w.content_type}' type='separator'>" +
                         "</item>"
        end
        prev_type = w.content_type
        w.title.gsub!(/'/, "&apos;")     # Need to escape single quote in title to load toolbar
        widget_list << "<item id='#{w.id}' type='button' text='#{CGI.escapeHTML(w.title)}' img='button_#{image}.png' title='#{tip}'>" +
                       "</item>"
      end
    end
    if role_allows(:feature => "dashboard_add") || role_allows(:feature => "dashboard_reset")
      @widgets_menu_xml = "<?xml version='1.0'?><toolbar>"
      if widget_list.blank?
        @widgets_menu_xml << "<item id='add_widget' type='buttonSelect' img='add_widget.png' \
                             imgdis='add_widget.png' title='No Widgets available to add' enabled='false'>\
                             </item>"
      else
        if role_allows(:feature => "dashboard_add")
          if @sb[:dashboards][@sb[:active_db]][:locked]
            title   = "Cannot add a Widget, this Dashboard has been locked by the Administrator"
            enabled = 'false'
          else
            title   = "Add a widget"
            enabled = 'true'
          end
          @widgets_menu_xml << "<item id='add_widget' type='buttonSelect' maxOpen='15' img='add_widget.png' title='#{title}' imgdis='add_widget.png' enabled='#{enabled}' openAll='true'>" +
                               widget_list +
                               "</item>"
        end
      end
      if role_allows(:feature=>"dashboard_reset")
        @widgets_menu_xml << "<item id='reset' type='button' img='reset_widgets.png' title='Reset Dashboard Widgets to the defaults'>" +
                             "</item>"
      end
      @widgets_menu_xml << "</toolbar>"
      @widgets_menu_xml = @widgets_menu_xml.html_safe
    end
  end

  # Destroy and recreate a user's dashboard from the default
  def reset_widgets
    assert_privileges("dashboard_reset")
    ws = MiqWidgetSet.where_unique_on(@sb[:active_db], session[:group], session[:userid]).first
    ws.destroy unless ws.nil?
    ws = create_user_dashboard(@sb[:active_db_id])
    @sb[:dashboards] = nil  # Reset dashboards hash so it gets recreated
    render :update do |page|
      page.redirect_to :action => 'show'
    end
  end

  # Toggle dashboard item size
  def widget_toggle_minmax
    unless params[:widget] # Make sure we got a widget in
      render :nothing => true
      return
    end

    w = params[:widget].to_i
    render :update do |page|
      if @sb[:dashboards][@sb[:active_db]][:minimized].include?(w)
        page << javascript_add_class("w_#{w}_minmax", "minbox")
        page << javascript_del_class("w_#{w}_minmax", "maxbox")
        page << javascript_show("dd_w#{w}_box")
        page << "$('#w_#{w}_minmax').prop('title', 'Minimize');"
        @sb[:dashboards][@sb[:active_db]][:minimized].delete(w)
      else
        page << javascript_add_class("w_#{w}_minmax", "maxbox")
        page << javascript_del_class("w_#{w}_minmax", "minbox")
        page << javascript_hide("dd_w#{w}_box")
        page << "$('#w_#{w}_minmax').prop('title', 'Restore');"
        @sb[:dashboards][@sb[:active_db]][:minimized].push(w)
      end
    end
    save_user_dashboards
  end

  # Zoom in on chart widget
  def widget_zoom
    unless params[:widget] # Make sure we got a widget in
      render :nothing => true
      return
    end

    widget = MiqWidget.find_by_id(params[:widget].to_i)
    # Save the rr id for render_zgraph
    @sb[:report_result_id] = widget.contents_for_user(session[:userid]).miq_report_result_id

    render :update do |page|
      page.replace_html("lightbox_div", :partial => "zoomed_chart", :locals => {:widget => widget})
      page << "$('#lightbox-panel').fadeIn(300);"
      page << "miqLoadCharts();"
    end
  end

  # A widget has been dropped
  def widget_dd_done
    if params[:col1] || params[:col2] || params[:col3]
      if params[:col1] && params[:col1] != [""]
        @sb[:dashboards][@sb[:active_db]][:col1] = params[:col1].collect{|w| w.split("_").last.to_i}
        @sb[:dashboards][@sb[:active_db]][:col2].delete_if{|w| @sb[:dashboards][@sb[:active_db]][:col1].include?(w)}
        @sb[:dashboards][@sb[:active_db]][:col3].delete_if{|w| @sb[:dashboards][@sb[:active_db]][:col1].include?(w)}
      elsif params[:col2] && params[:col2] != [""]
        @sb[:dashboards][@sb[:active_db]][:col2] = params[:col2].collect{|w| w.split("_").last.to_i}
        @sb[:dashboards][@sb[:active_db]][:col1].delete_if{|w| @sb[:dashboards][@sb[:active_db]][:col2].include?(w)}
        @sb[:dashboards][@sb[:active_db]][:col3].delete_if{|w| @sb[:dashboards][@sb[:active_db]][:col2].include?(w)}
      elsif params[:col3] && params[:col3] != [""]
        @sb[:dashboards][@sb[:active_db]][:col3] = params[:col3].collect{|w| w.split("_").last.to_i}
        @sb[:dashboards][@sb[:active_db]][:col1].delete_if{|w| @sb[:dashboards][@sb[:active_db]][:col3].include?(w)}
        @sb[:dashboards][@sb[:active_db]][:col2].delete_if{|w| @sb[:dashboards][@sb[:active_db]][:col3].include?(w)}
      end
      save_user_dashboards
    end
    render :nothing=>true               # We have nothing to say  :)
  end

  # A widget has been closed
  def widget_close
    if params[:widget]                # Make sure we got a widget in
      w = params[:widget].to_i
      @sb[:dashboards][@sb[:active_db]][:col1].delete(w)
      @sb[:dashboards][@sb[:active_db]][:col2].delete(w)
      @sb[:dashboards][@sb[:active_db]][:col3].delete(w)
      @sb[:dashboards][@sb[:active_db]][:minimized].delete(w)
      ws = MiqWidgetSet.where_unique_on(@sb[:active_db], session[:group], session[:userid]).first
      w = MiqWidget.find_by_id(w)
      ws.remove_member(w) if w
      save_user_dashboards
      render :update do |page|
        page.redirect_to :action => 'show'
      end
    else
      render :nothing => true
    end
  end

  # A widget has been added
  def widget_add
    assert_privileges("dashboard_add")
    if params[:widget]                # Make sure we got a widget in
      w = params[:widget].to_i
      if @sb[:dashboards][@sb[:active_db]][:col3].length < @sb[:dashboards][@sb[:active_db]][:col1].length &&
          @sb[:dashboards][@sb[:active_db]][:col3].length < @sb[:dashboards][@sb[:active_db]][:col2].length
        @sb[:dashboards][@sb[:active_db]][:col3].insert(0, w)
      elsif @sb[:dashboards][@sb[:active_db]][:col2].length < @sb[:dashboards][@sb[:active_db]][:col1].length
        @sb[:dashboards][@sb[:active_db]][:col2].insert(0, w)
      else
        @sb[:dashboards][@sb[:active_db]][:col1].insert(0, w)
      end
      ws = MiqWidgetSet.where_unique_on(@sb[:active_db], session[:group], session[:userid]).first
      w = MiqWidget.find_by_id(w)
      ws.add_member(w) if w
      save_user_dashboards
      w.create_initial_content_for_user(session[:userid])
      render :update do |page|
        page.redirect_to :action => 'show'
      end
    else
      render :nothing => true
    end
  end

  # Methods to handle login/authenticate/logout functions
  def login
    if get_vmdb_config[:product][:allow_passed_in_credentials]  # Only pre-populate credentials if setting is turned on
      @user_name     = params[:user_name]
      @user_password = params[:user_password]
    end
    css = @settings[:css] if @settings && @settings[:css] # Save prior CSS settings
    @settings = copy_hash(DEFAULT_SETTINGS)               # Need settings, else pages won't display
    @settings[:css] = css if css                          # Restore CSS settings for other tabs previusly logged in
    @more = params[:type] && params[:type] != "less"
    flash[:notice] = _("Session was timed out due to inactivity. Please log in again.") if params[:timeout] == "true"
    logon_details = MiqServer.my_server(true).logon_status_details
    @login_message = logon_details[:message] if logon_details[:status] == :starting && logon_details[:message]

    render :layout => "login"
  end

  # AJAX login retry method
  def login_retry
    render :update do |page|                    # Use RJS to update the display
#     if MiqServer.my_server(true).logon_status == :starting
      logon_details = MiqServer.my_server(true).logon_status_details
      if logon_details[:status] == :starting
        @login_message = logon_details[:message] if logon_details[:message]
        page.replace("login_message_div", :partial=>"login_message")
        page << "setTimeout(\"#{remote_function(:url=>{:action=>'login_retry'})}\", 10000);"
      else
        page.redirect_to :action => 'login'
      end
    end
  end

  # Handle single-signon from login screen
  def kerberos_authenticate
    if @user_name.blank? && request.env.key?("HTTP_X_REMOTE_USER").present?
      @user_name = params[:user_name] = request.env["HTTP_X_REMOTE_USER"].split("@").first
    end

    authenticate
  end

  # Handle user credentials from login screen
  def authenticate
    @layout = "dashboard"

    unless params[:task_id] # First time thru, check for buttons pressed
      # Handle More and Back buttons (for changing password)
      case params[:button]
      when "more"
        @more = true
        render :update do |page|
          page.replace("login_more_div", :partial => "login_more")
          page << javascript_focus('user_new_password')
          page << javascript_show("back_button")
          page << javascript_hide("more_button")
        end
        return
      when "back"
        render :update do |page|
          page.replace("login_more_div", :partial => "login_more")
          page << javascript_focus('user_name')
          page << javascript_hide("back_button")
          page << javascript_show("more_button")
        end
        return
      end
    end

    user = {
      :name            => params[:user_name],
      :password        => params[:user_password],
      :new_password    => params[:user_new_password],
      :verify_password => params[:user_verify_password]
    }

    if params[:user_name].blank? && params[:user_password].blank? &&
      request.env["HTTP_X_REMOTE_USER"].blank? &&
      get_vmdb_config[:authentication][:mode] == "httpd" &&
      get_vmdb_config[:authentication][:sso_enabled] &&
      params[:action] == "authenticate"

      render :update do |page|
        page.redirect_to(root_path)
      end
      return
    end

    validation = validate_user(user, params[:task_id], request)
    case validation.result
    when :wait_for_task
      # noop, page content already set by initiate_wait_for_task
    when :pass
      session['referer'] = request.base_url + '/'
      render :update do |page|
        page.redirect_to(validation.url)
      end
    when :fail
      session[:userid], session[:username], session[:user_tags] = nil
      add_flash(validation.flash_msg || "Error: Authentication failed", :error)
      render :update do |page|
        page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        page << javascript_show("flash_div")
        page << "miqSparkle(false);"
        page << "miqEnableLoginFields(true);"
      end
    end
  end

  def timeline
    @breadcrumbs = []
    @layout      = "timeline"
    @report      = nil
    @timeline    = true
    if params[:id]
      build_timeline
      drop_breadcrumb(:name => @title, :url => "/dashboard/timeline/#{params[:id]}")
    else
      drop_breadcrumb(:name => "Timelines", :url => "/dashboard/timeline")
      session[:last_rpt_id] = nil # Clear out last rpt record id
    end
    build_timeline_listnav
  end

  def show_timeline
    @breadcrumbs = []
    @layout      = "timeline"
    if params[:id]
      build_timeline
      render :update do |page|
        if @ajax_action
          page << "miqAsyncAjax('#{url_for(:action => @ajax_action, :id => @record)}');"
        end
      end
    else
      @report = nil
      drop_breadcrumb(:name => "Timelines", :url => "/dashboard/timeline")
      @timeline = true
      session[:last_rpt_id] = nil # Clear out last rpt record id
      build_timeline_listnav
    end
  end

  # Process changes to timeline selection
  def tl_generate
    # set variables for type of timeline is selected
    unless @temp[:timeline]
      tl_gen_timeline_data
      return unless @temp[:timeline]
    end

    @temp[:timeline] = true
    render :update do |page|
      page << javascript_highlight("report_#{session[:last_rpt_id]}_link", false)  if session[:last_rpt_id]
      center_tb_buttons = {
        'timeline_txt' => "text",
        'timeline_csv' => "CSV"
      }
      center_tb_buttons['timeline_pdf'] = "PDF" if PdfGenerator.available?
      if @report
        page << javascript_highlight("report_#{@report.id}_link", true)
        status = @report.table.data.length == 0 ? :disabled : :enabled

        center_tb_buttons.each do |button_id, typ|
          page << "center_tb.showItem('#{button_id}');"
          page << tl_toggle_button_enablement(button_id, status, typ)
        end
      else
        center_tb_buttons.keys.each do |button_id|
          page << "center_tb.hideItem('#{button_id}');"
        end
      end
      page.replace("tl_div", :partial => "dashboard/tl_detail")
      page << "miqSparkle(false);"
      session[:last_rpt_id] = @report ? @report.id : nil  # Remember rpt record id to turn off later
    end
  end

  def getTLdata
    if session[:tl_xml_blob_id] != nil
      blob = BinaryBlob.find(session[:tl_xml_blob_id])
      render :xml=>blob.binary
      blob.destroy
      session[:tl_xml_blob_id] = session[:tl_position] = nil
    else
      tl_xml = MiqXml.load("<data/>")
      #   tl_event = tl_xml.root.add_element("event", {
      #                                                   "start"=>"May 16 2007 08:17:23 GMT",
      #                                                   "title"=>"Dans-XP-VM",
      #                                                   "image"=>"images/icons/20/20-VMware.png",
      #                                                   "text"=>"VM &lt;a href=\"/vm/guest_applications/3\"&gt;Dan-XP-VM&lt;/a&gt; cloned to &lt;a href=\"/vm/guest_applications/1\"&gt;WinXP Testcase&lt;/a&gt;."
      #                                                   })
      Vm.all.each do | vm |
        event = tl_xml.root.add_element("event", {
#           START of TIMELINE TIMEZONE Code
            "start"=>format_timezone(vm.created_on,Time.zone,"tl"),
#           "start"=>vm.created_on,
#           END of TIMELINE TIMEZONE Code
            #                                       "end" => Time.now,
            #                                       "isDuration" => "true",
            "title"=>vm.name.length < 25 ? vm.name : vm.name[0..22] + "...",
            #                                       "title"=>vm.name,
            #"image"=>"/images/icons/20/20-#{vm.vendor.downcase}.png"
            "icon"=>"/images/icons/timeline/vendor-#{vm.vendor.downcase}.png",
            "color"=>"blue",
            #"image"=>"/images/icons/64/64-vendor-#{vm.vendor.downcase}.png"
            "image"=>"/images/icons/new/os-#{vm.os_image_name.downcase}.png"
            #                                       "text"=>"VM &lt;a href='/vm/guest_applications/#{vm.id}'&gt;#{h(vm.name)}&lt;/a&gt; discovered at location #{h(vm.location)}&gt;."
          })
        #     event.text = "VM #{vm.name} discovered on #{vm.created_on}"
        event.text = "VM &lt;a href='/vm/guest_applications/#{vm.id}'&gt;#{vm.name}&lt;/a&gt; discovered at location #{vm.location}"
      end
      render :xml=>tl_xml.to_s
    end
  end

  def logout
    user = User.find_by_userid(session[:userid])
    user.logoff if user

    session.clear
    session[:auto_login] = false
    redirect_to :action => 'login'
  end

  # User request to change to a different eligible group
  def change_group
    # Get the user and new group and set current_group in the user record
    db_user = User.find_by_userid(session[:userid])
    to_group = MiqGroup.find_by_id(params[:to_group])
    db_user.current_group = to_group
    db_user.save

    # Rebuild the session
    session_reset(db_user)
    session_init(db_user)
    session[:group_changed] = true
    url = start_url_for_user(nil) || url_for(:controller => params[:controller], :action => 'show')
    render :update do |page|
      page.redirect_to(url)
    end
  end

  private

  def tl_toggle_button_enablement(button_id, enablement, typ)
    if enablement == :enabled
      tooltip = "Download this Timeline data in #{typ} format"
      "center_tb.enableItem('#{button_id}'); center_tb.setItemToolTip('#{button_id}', '#{tooltip}');"
    else
      tooltip = 'No records found for this timeline'
      "center_tb.disableItem('#{button_id}'); center_tb.setItemToolTip('#{button_id}', '#{tooltip}');"
    end
  end
  helper_method(:tl_toggle_button_enablement)

  def validate_user(user, task_id = nil, request = nil)
    UserValidationService.new(self).validate_user(user, task_id, request)
  end

  def start_url_for_user(start_url)
    return url_for(start_url) unless start_url.nil?
    return url_for(:action => "show") unless @settings[:display][:startpage]

    first_allowed_url = nil
    startpage_already_set = nil
    MiqShortcut.start_pages.each do |url, _description, rbac_feature_name|
      allowed = start_page_allowed?(rbac_feature_name)
      first_allowed_url ||= url if allowed
      # if default startpage is set, check if it is allowed
      startpage_already_set = true if @settings[:display][:startpage] == url && allowed
      break if startpage_already_set
    end

    # user first_allowed_url in start_pages to be default page, if default startpage is not allowed
    @settings[:display][:startpage] = first_allowed_url unless startpage_already_set
    @settings[:display][:startpage]
  end

  # Reset and set the user vars in the session object
  def session_reset(db_user)  # User record
    # Clear session hash just to be sure nothing is left (but copy over some fields)
    winh    = session[:winH]
    winw    = session[:winW]
    referer = session['referer']

    session.clear

    session[:winH]     = winh
    session[:winW]     = winw
    session['referer'] = referer

    return nil if db_user.nil? || !db_user.userid
    session[:userid] = db_user.userid

    # Set the current userid in the User class for this thread for models to use
    User.current_userid = session[:userid]

    session[:username] = db_user.name

    # set group and role ids
    return nil unless db_user.current_group
    session[:group] = db_user.current_group.id              # Set the user's group id
    session[:group_description] = db_user.current_group.description # and description
    role = db_user.current_group.miq_user_role
    return nil unless db_user.current_group.miq_user_role
    session[:role] = role.id                            # Set the group's role id

    # Build pre-sprint 69 role name if this is an EvmRole read_only role
    session[:userrole] = role.read_only? ? role.name.split("-").last : ""

    # Save an array of groups this user is eligible for, if more than 1
    eligible_groups = db_user.miq_groups.sort_by { |g| g.description.downcase }
    session[:eligible_groups] = db_user.nil? || eligible_groups.length < 2 ?
        [] :
        eligible_groups.collect{|g| [g.description, g.id]}

    # Clear instance vars that end up in the session
    @sb = @edit = @view = @settings = @lastaction = @perf_options = @assign =
        @current_page = @search_text = @detail_sortcol = @detail_sortdir =
            @exp_key = @server_options = @tl_options =
                @pp_choices = @panels = @breadcrumbs = nil
    true
  end

  # Initialize session hash variables for the logged in user
  def session_init(db_user)
    session[:user_tags] = db_user.tag_list unless db_user == nil      # Get user's tags

    # Load settings for this user, if they exist
    @settings = copy_hash(DEFAULT_SETTINGS)             # Start with defaults
    unless db_user == nil || db_user.settings == nil    # If the user has saved settings

      db_user.settings.delete(:dashboard)               # Remove pre-v4 dashboard settings
      db_user.settings.delete(:db_item_min)

      @settings.each { |key, value| value.merge!(db_user.settings[key]) unless db_user.settings[key] == nil }
      @settings[:col_widths] = db_user.settings[:col_widths]  # Get the user's column widths
      @settings[:default_search] = db_user.settings[:default_search]  # Get the user's default search setting
    end

    # Copy ALL display settings into the :css hash so we can easily add new settings
    @settings[:css] ||= Hash.new
    @settings[:css].merge!(@settings[:display])
    @settings[:display][:theme] = THEMES.first.last unless THEMES.collect(&:last).include?(@settings[:display][:theme])
    @settings[:css].merge!(THEME_CSS_SETTINGS[@settings[:display][:theme]])

    @css ||= Hash.new
    @css.merge!(@settings[:display])
    @css.merge!(THEME_CSS_SETTINGS[@settings[:display][:theme]])

    session[:user_TZO] = params[:user_TZO] ? params[:user_TZO].to_i : nil     # Grab the timezone (future use)
    session[:browser] ||= Hash.new("Unknown")
    session[:browser][:name] = params[:browser_name] if params[:browser_name]
    session[:browser][:version] = params[:browser_version] if params[:browser_version]
    session[:browser][:os] = params[:browser_os] if params[:browser_os]
  end

  # Create a user's dashboard, pass in dashboard id if that is used to copy else use default dashboard
  def create_user_dashboard(db_id = nil)
    db = db_id ? MiqWidgetSet.find_by_id(db_id) : MiqWidgetSet.where_unique_on("default", nil, nil).first
    ws = MiqWidgetSet.where_unique_on(db.name, session[:group], session[:userid]).first
    if ws.nil?
      # Create new db if it doesn't exist
      ws = MiqWidgetSet.new(:name       => db.name,
                            :group_id   => session[:group],
                            :userid     => session[:userid],
                            :description=>"#{db.name} dashboard for user #{session[:userid]} in group id #{session[:group]}")
      ws.set_data = db.set_data
      ws.set_data[:last_group_db_updated] = db.updated_on
      ws.save!
      ws.replace_children(db.children)
      ws.members.each{|w| w.create_initial_content_for_user(session[:userid])}  # Generate content if not there
    end
    if !db_id     #set active_db and id and tabs now if user's group didnt have any dashboards
      @sb[:active_db] = db.name
      @sb[:active_db_id] = db.id
    end
    return ws
  end

  # Save dashboards for user
  def save_user_dashboards
    ws = MiqWidgetSet.where_unique_on(@sb[:active_db], session[:group], session[:userid]).first
    ws.set_data = @sb[:dashboards][@sb[:active_db]]
    ws.save
  end

  # Gather information for the report accordians
  def build_timeline_listnav
    build_report_listnav("timeline")
  end

  def build_timeline
    @record = MiqReport.find_by_id(from_cid(params[:id]))
    @ajax_action = "tl_generate"
  end

  def tl_gen_timeline_data
    @report = MiqReport.find(from_cid(params[:id]))
    @title  = @report.title
    @temp[:timeline] = true unless @report # need to set this incase @report is not there, when switching between Management/Policy events
    return unless @report

    unless params[:task_id] # First time thru, kick off the report generate task
      options = {:userid => session[:userid]}
      initiate_wait_for_task(:task_id => @report.async_generate_table(options))
      return
    end

    @temp[:timeline] = true
    miq_task = MiqTask.find(params[:task_id]) # Not first time, read the task record
    @report  = miq_task.task_results
    session[:rpt_task_id] = miq_task.id
    if miq_task.task_results.blank? || miq_task.status != "Ok" # Check to see if any results came back or status not Ok
      add_flash(_("Error building timeline ") << miq_task.message, :error)
      return
    end

    @timeline = true
    if @report.table.data.empty?
      add_flash(_("No records found for this timeline"), :warning)
      return
    end

    @report.extras[:browser_name] = browser_info("name").downcase
    if is_browser_ie?
      blob = BinaryBlob.new(:name => "timeline_results")
      blob.binary = @report.to_timeline
      session[:tl_xml_blob_id] = blob.id
    else
      @temp[:tl_json] = @report.to_timeline
    end

    tz = @report.tz || Time.zone
    session[:tl_position] = format_timezone(@report.extras[:tl_position], tz, "tl")
  end

  def get_layout
    # Don't change layout when window size changes session[:layout]
    request.parameters["action"] == "window_sizes" ? session[:layout] : "login"
  end

  def get_session_data
    @layout       = get_layout
    @current_page = session[:vm_current_page] # current page number
  end

  def set_session_data
    session[:layout]          = @layout
    session[:vm_current_page] = @current_page
  end

end
