class DashboardController < ApplicationController
  @@items_per_page = 8

  before_filter :check_privileges, :except => [:csp_report, :window_sizes, :authenticate, :logout, :login, :login_retry, :wait_for_task]
  before_filter :get_session_data, :except => [:csp_report, :window_sizes, :authenticate]
  after_filter :cleanup_action,    :except => [:csp_report]
  after_filter :set_session_data,  :except => [:csp_report, :window_sizes]

  def index
    redirect_to :action => 'show'
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
    :vi, :svc, :clo, :inf, :con, :aut, :opt, :set,  # normal tabs
    :vs, :vdi, :sto                                 # hidden tabs
  ]] # format is {"vi" => :vi, "svc" => :svc . . }

  EXPLORER_FEATURE_LINKS = {
      "catalog"                   => "catalog",
      "pxe"                       => "pxe",
      "service"                   => "service",
      "vm_cloud_explorer_accords" => "vm_cloud",
      "vm_explorer_accords"       => "vm_or_template",
      "vm_infra_explorer_accords" => "vm_infra"
  }

  # A main tab was pressed
  def maintab
    tab = VALID_TABS[params[:tab]]

    unless tab # no tab name or invalid tab name was passed in
      render :action => "login"
      return
    end

    case tab
    when :vi, :svc, :clo, :inf, :con, :aut, :opt, :set

      if session[:tab_url].key?(tab) # we remember url for this tab
        redirect_to(session[:tab_url][tab].merge(:only_path => true))
        return
      end

      tab_features = MAIN_TAB_FEATURES.collect { |f| f.last if f.first == MAIN_TABS[tab] }.compact.first
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
      when :clo, :inf, :svc
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
            when "tasks"        then redirect_to(:controller => "miq_proxy", :action => "index")
            when "ops_explorer" then redirect_to(:controller => "ops",       :action => "explorer")
            when "miq_proxy"    then redirect_to(:controller => "miq_proxy", :action => "show_list")
            when "about"        then redirect_to(:controller => "support",   :action => "index", :support_tab => "about")
            end
          end
        end
      end
    else
      tab_features = MAIN_TAB_FEATURES.collect { |f| f.last if f.first == MAIN_TABS[tab] }.compact.first
      if Array(session[:tab_bc][tab]).empty? # no saved breadcrumbs for this tab
        case tab
        when :vs
          redirect_to :controller => "service"
        when :vdi, :sto
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
      # load first one on intial load, or load tab from params[:tab] changed, or when coming back from another screen load active tab from sandbox
      if (!params[:tab] && !@sb[:active_db_id] && i == 0) || (params[:tab] && params[:tab] == db.id.to_s) ||
         (!params[:tab] && @sb[:active_db_id] && @sb[:active_db_id].to_s == db.id.to_s)
        @tabs.unshift([db.id.to_s, ""])
        @sb[:active_db]    = db.name
        @sb[:active_db_id] = db.id
      end
      @tabs.push([db.id.to_s,db.description])

      unless @sb[:dashboards] # check this only first time when user logs in comes to dashboard show
        # get user dashboard version
        ws = MiqWidgetSet.where_unique_on(db.name, session[:group], session[:userid]).first
        # update user's copy if group dashboard has been updated by admin
        if ws && ws.set_data && (!ws.set_data[:last_group_db_updated] || (ws.set_data[:last_group_db_updated] && db.updated_on > ws.set_data[:last_group_db_updated]))
          #if group dashboard was locked earlier but now it is unlocked, reset everything  OR if admin makes changes to a locked db do a reset on user's copies
          if (db.set_data[:locked] && !ws.set_data[:locked]) || (db.set_data[:locked] && ws.set_data[:locked])
            ws.set_data = db.set_data
            ws.set_data[:last_group_db_updated] = db.updated_on
            ws.save
          # if group dashboard was unloacked earlier but now it is locked, only change locked flag of users dashboard version
          elsif !db.set_data[:locked] && ws.set_data[:locked]
            ws.set_data[:locked] = db.set_data[:locked]
            ws.set_data[:last_group_db_updated] = db.updated_on if !ws.set_data[:last_group_db_updated]
            ws.save
          end
        end
      end
    end

    @sb[:dashboards] ||= {}
    ws = MiqWidgetSet.where_unique_on(@sb[:active_db], session[:group], session[:userid]).first
    if ws.nil? # if all of user groups dashboards have been deleted and they are logged in, need to reset active_db_id
      wset = MiqWidgetSet.find_by_id(@sb[:active_db_id])
      @sb[:active_db_id] = nil if wset.nil?
    end
    ws = create_user_dashboard(@sb[:active_db_id]) if ws.nil?   # Create default dashboard for this user, if not present

    if db_order.empty?    # Set tabs now if user's group didnt have any dashboards using default dashboard
      db = MiqWidgetSet.find_by_id(@sb[:active_db_id])
      @tabs.unshift([ws.id.to_s, ""])
      @tabs.push([ws.id.to_s, db.description])
    else                # User's group has dashboards, delete userid|default dashboard if it exists, dont need to keep that
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
      ie8_safe_redirect(page, url_for(:controller => params[:controller], :action => 'show'))
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
        page << "$('w_#{w}_minmax').addClassName('minbox');"
        page << "$('w_#{w}_minmax').removeClassName('maxbox');"
        page << "$('dd_w#{w}_box').show();"
        page << "$('w_#{w}_minmax').title = 'Minimize';"
        @sb[:dashboards][@sb[:active_db]][:minimized].delete(w)
      else
        page << "$('w_#{w}_minmax').addClassName('maxbox');"
        page << "$('w_#{w}_minmax').removeClassName('minbox');"
        page << "$('dd_w#{w}_box').hide();"
        page << "$('w_#{w}_minmax').title = 'Restore';"
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
      page << "$j('#lightbox-panel').fadeIn(300);"
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
        ie8_safe_redirect(page, url_for(:controller => params[:controller], :action => 'show'))
      end
    else
      render :nothing=>true               # We have nothing to say  :)
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
        ie8_safe_redirect(page, url_for(:controller => params[:controller], :action => 'show'))
      end
    else
      render :nothing=>true               # We have nothing to say  :)
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
    flash[:notice] = I18n.t('flash.authentication.session_timed_out') if params[:timeout] == "true"
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

  # Handle user credentials from login screen
  def authenticate
    @layout = "dashboard"

    unless params[:task_id] # First time thru, check for buttons pressed
      # Handle More and Back buttons (for changing password)
      if params[:button] == "more"
        @more = true
        render :update do |page|
          page.replace("login_more_div", :partial=>"login_more")
          page << "$('user_new_password').focus();"
          page << "$('back_button').show();"
          page << "$('more_button').hide();"
        end
        return
      elsif params[:button] == "back"
        render :update do |page|
          page.replace("login_more_div", :partial=>"login_more")
          page << "$('user_name').focus();"
          page << "$('back_button').hide();"
          page << "$('more_button').show();"
        end
        return
      end
    end

    user = {
      :name             =>  params[:user_name],
      :password         =>  params[:user_password],
      :new_password     =>  params[:user_new_password],
      :verify_password  =>  params[:user_verify_password]
    }

    url = validate_user(user)

    unless @wait_for_task
      render :update do |page|
        if url  # User is logged in, redirect to URL
          session['referer'] = request.base_url + '/'

          ie8_safe_redirect(page, url)
        else    # No URL, show error msg
          @flash_msg ||= "Error: Authentication failed"
          session[:userid], session[:username], session[:user_tags] = nil
          page.replace_html('flash_div', @flash_msg)
          page << "$('flash_div').show();"
#         page << "$('flash_div').visualEffect('pulsate');"
          page << "miqSparkle(false);"
          page << "miqEnableLoginFields(true);"
        end
      end
    end
  end

  def timeline
    @breadcrumbs = Array.new
    @layout = "timeline"
    @report = nil
    @timeline = true
    if params[:id]
      build_timeline                            # Create the timeline report
      drop_breadcrumb( {:name=>@title, :url=>"/dashboard/timeline/#{params[:id]}"})
    else
      drop_breadcrumb( {:name=>"Timelines", :url=>"/dashboard/timeline"})
      session[:last_rpt_id] = nil               # Clear out last rpt record id
    end
    build_timeline_listnav
  end

  def show_timeline
    @breadcrumbs = Array.new
    @layout = "timeline"
    if params[:id]
      build_timeline                            # Create the timeline report
      render :update do |page|
        if @ajax_action
          page << "miqAsyncAjax('#{url_for(:action=>@ajax_action, :id=>@record)}');"
        end
      end
    else
      @report = nil
      drop_breadcrumb( {:name=>"Timelines", :url=>"/dashboard/timeline"})
      @timeline = true
      session[:last_rpt_id] = nil               # Clear out last rpt record id
      build_timeline_listnav
    end
  end

  # Process changes to timeline selection
  def tl_generate
    # set variables for type of timeline is selected
    if !@temp[:timeline]
      tl_gen_timeline_data
      return unless @temp[:timeline]
    end

    @temp[:timeline] = true
    render :update do |page|
      page << "miqHighlight('report_#{session[:last_rpt_id]}_link', false);" if session[:last_rpt_id]
      if @report
        page << "miqHighlight('report_#{@report.id}_link', true);"
        page << "center_tb.showItem('timeline_txt');"
        page << "center_tb.showItem('timeline_csv');"
        page << "center_tb.showItem('timeline_pdf');"
        if @report.table.data.length == 0
          page << "center_tb.disableItem('timeline_txt');"
          page << "center_tb.setItemToolTip('timeline_txt','No records found for this timeline');"
          page << "center_tb.disableItem('timeline_csv');"
          page << "center_tb.setItemToolTip('timeline_csv','No records found for this timeline');"
          page << "center_tb.disableItem('timeline_pdf');"
          page << "center_tb.setItemToolTip('timeline_pdf','No records found for this timeline');"
        else
          page << "center_tb.enableItem('timeline_txt');"
          page << "center_tb.setItemToolTip('timeline_txt','Download this Timeline data in text format');"
          page << "center_tb.enableItem('timeline_csv');"
          page << "center_tb.setItemToolTip('timeline_csv','Download this Timeline data in CSV format');"
          page << "center_tb.enableItem('timeline_pdf');"
          page << "center_tb.setItemToolTip('timeline_pdf','Download this Timeline data in PDF format');"
        end
      else
        page << "center_tb.hideItem('timeline_txt');"
        page << "center_tb.hideItem('timeline_csv');"
        page << "center_tb.hideItem('timeline_pdf');"
      end
      page.replace("tl_div", :partial=>"dashboard/tl_detail")
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
    url = start_url_for_user(nil)
    render :update do |page|
      if url
        ie8_safe_redirect(page, url)
      else
        ie8_safe_redirect(page, url_for(:controller => params[:controller], :action => 'show'))
      end
    end
  end

  private ###########################

  # Validate user login credentials - return <url for redirect> or nil if an error
  def validate_user(user)
    unless params[:task_id]                       # First time thru, kick off authenticate task

      # Pre_authenticate checks
      if user.blank? || user[:name].blank?
        @flash_msg = "Error: Name is required"
        return nil
      end
      if user[:new_password] != nil && user[:new_password] != user[:verify_password]
        @flash_msg = "Error: New password and verify password must be the same"
        return nil
      end
      if user[:new_password] != nil && user[:new_password].blank?
        @flash_msg = "Error: New password can not be blank"
        return nil
      end
      if user[:new_password] != nil && user[:password] == user[:new_password]
        @flash_msg = "Error: New password is the same as existing password"
        return nil
      end

      # Call the authentication, use wait_for_task if a task is spawned
      begin
        user_or_taskid = User.authenticate(user[:name],user[:password])
      rescue MiqException::MiqEVMLoginError => err
        @flash_msg = I18n.t("flash.authentication.error")
        user[:name] = nil
        return
      end
      if user_or_taskid.kind_of?(User)
        user[:name] = user_or_taskid.userid
      else
        initiate_wait_for_task(:task_id => user_or_taskid) # Wait for the task to complete
        @wait_for_task = true
        return
      end
    else
      task = MiqTask.find_by_id(params[:task_id])
      if task.status.downcase != "ok"
        @flash_msg = "Error: " + task.message
        task.destroy
        return
      end
      user[:name] = task.userid
      task.destroy
    end

    if user[:name]
      if user[:new_password] != nil
        begin
          User.find_by_userid(user[:name]).change_password(user[:password], user[:new_password])
        rescue StandardError => bang
          @flash_msg = "Error: " + bang.message
          return nil
        end
      end

      db_user = User.find_by_userid(user[:name])

      start_url = session[:start_url] # Hang on to the initial start URL
      session_reset(db_user)          # Reset/recreate the session hash

      # If a main db is specified, don't allow logins until super admin has set up the system
      if session[:userrole] != 'super_administrator' &&
        get_vmdb_config[:product][:maindb] &&
          ! Vm.first &&
          ! Host.first
        @flash_msg = "The system has not been configured, please contact the administrator"
        return nil
      end

      session_init(db_user)    # Initialize the session hash variables

      if MiqServer.my_server(true).logon_status != :ready
        if session[:userrole] == 'super_administrator'
          return url_for(:controller=>"ops",
                        :action=>'explorer',
                        :flash_warning=>true,
                        :no_refresh=>true,
                        :flash_msg=>I18n.t("flash.server_still_starting_admin"),
                        :escape=>false)
        else
          @flash_msg = I18n.t("flash.server_still_starting")
          return nil
        end
      end

      # Start super admin at the main db if the main db has no records yet
      if session[:userrole] == 'super_administrator' &&
        get_vmdb_config[:product][:maindb] && !get_vmdb_config[:product][:maindb].constantize.first
        if get_vmdb_config[:product][:maindb] == "Host"
          return url_for(:controller=>"Host",
                        :action=>'show_list',
                        :flash_warning=>true,
                        :flash_msg=>I18n.t("flash.no_host_defined"))
        elsif get_vmdb_config[:product][:maindb] == "EmsInfra"
          return url_for(:controller=>"ems_infra",
                        :action=>'show_list',
                        :flash_warning=>true,
                        :flash_msg=>I18n.t("flash.no_vc_defined"))
        end
      end

      return start_url_for_user(start_url)
    end

    session[:userid], session[:username], session[:user_tags] = nil
    User.current_userid = nil
    @flash_msg ||= "Error: Authentication failed"
    return nil
  end

  def start_url_for_user(start_url)
    return url_for(start_url) unless start_url.nil?
    return url_for(:action => "show") unless @settings[:display][:startpage]

    first_allowed_url = nil
    startpage_already_set = nil
    MiqShortcut.start_pages.each do |url, _description, rbac_feature_name|
      allowed = role_allows(:feature => rbac_feature_name, :any => true)
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

    session[:userid] = db_user.userid

    # Set the current userid in the User class for this thread for models to use
    User.current_userid = session[:userid]

    session[:username] = db_user.name

    # set group and role ids
    session[:group] = db_user.current_group.id              # Set the user's group id
    session[:group_description] = db_user.current_group.description # and description
    role = db_user.current_group.miq_user_role
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
    @settings[:display][:theme] = THEMES.first.last unless THEMES.collect{|t| t.last}.include?(@settings[:display][:theme])
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
    @title = @report.title
    @temp[:timeline] = true if !@report         # need to set this incase @report is not there, when switching between Management/Policy events
    if @report
      unless params[:task_id]                                     # First time thru, kick off the report generate task
        options = {:userid => session[:userid]}
        initiate_wait_for_task(:task_id => @report.async_generate_table(options))
        return
      end
      @temp[:timeline] = true
      miq_task = MiqTask.find(params[:task_id])     # Not first time, read the task record
      tz = @report.tz ? @report.tz : Time.zone
      @report = miq_task.task_results
      if miq_task.task_results.blank? || miq_task.status != "Ok"  # Check to see if any results came back or status not Ok
        add_flash(I18n.t("flash.error_building_timeline") << miq_task.message, :error)
      else
        @timeline = true
        if @report.table.data.length == 0
          add_flash(I18n.t("flash.no_timeline_records_found"), :warning)
        else
          @report.extras[:browser_name] = browser_info("name").downcase
          if is_browser_ie?
            blob = BinaryBlob.new(:name => "timeline_results")
            blob.binary=(@report.to_timeline)
            session[:tl_xml_blob_id] = blob.id
          else
            @temp[:tl_json] = @report.to_timeline
          end
          session[:tl_position] = format_timezone(@report.extras[:tl_position],tz,"tl")
        end
      end
    end
  end

  def get_session_data
      if request.parameters["action"] == "window_sizes" # Don't change layout when window size changes
      @layout = session[:layout]
      else
      @layout = ["my_tasks","timeline","my_ui_tasks"].include?(session[:layout]) ? session[:layout] : "dashboard"
      end
    @report       = session[:report]
    @current_page = session[:vm_current_page] # current page number
  end

  def set_session_data
    session[:layout]          = @layout
    session[:report]          = @report
    session[:vm_current_page] = @current_page
  end

end
