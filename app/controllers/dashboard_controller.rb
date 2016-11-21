class DashboardController < ApplicationController
  include DashboardHelper
  include StartUrl

  menu_section :vi

  @@items_per_page = 8

  before_action :check_privileges, :except => [:csp_report, :authenticate,
                                               :external_authenticate, :kerberos_authenticate,
                                               :logout, :login, :login_retry, :wait_for_task,
                                               :saml_login, :initiate_saml_login]
  before_action :get_session_data, :except => [:csp_report, :authenticate,
                                               :external_authenticate, :kerberos_authenticate, :saml_login]
  after_action :cleanup_action,    :except => [:csp_report]
  after_action :set_session_data,  :except => [:csp_report]

  def index
    redirect_to :action => 'show'
  end

  def saml_protected_page
    request.base_url + '/saml_login'
  end
  helper_method :saml_protected_page

  def iframe
    override_content_security_policy_directives(:frame_src => ['*'])
    override_x_frame_options('')
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
    head :ok
  end

  def resize_layout
    if params[:sidebar] && params[:context] && !params[:context].blank?
      session[:sidebar] ||= {}
      session[:sidebar][params[:context]] ||= 2
      sidebar = params[:sidebar].to_i
      session[:sidebar][params[:context]] = sidebar if [0, 2, 3, 4, 5].include?(sidebar)
    end
    head :ok # No response required
  end

  # Redirect to remembered last item clicked under this menu section.
  def redirect_to_remembered(section_id)
    return false unless session[:tab_url].key?(section_id)
    redirect_to(session[:tab_url][section_id])
    true
  end

  # Main menu section was clicked
  def maintab
    @breadcrumbs.clear

    section = Menu::Manager.section(params[:tab])
    if section.nil?
      render :action => "login"
      return
    end

    return if redirect_to_remembered(section.id)
    redirect_to(section.default_redirect_url)
  end

  # New tab was pressed
  def change_tab
    show
    render :action => "show"
  end

  def show
    @layout    = "dashboard"
    @dashboard = true
    @display = "dashboard"
    @lastaction = "show"

    records = current_group.ordered_widget_sets

    @tabs = []
    active_tab_id = (params[:tab] || @sb[:active_db_id]).try(:to_s)
    active_tab = active_tab_id && records.detect { |r| r.id.to_s == active_tab_id } || records.first
    # load first one on intial load, or load tab from params[:tab] changed,
    # or when coming back from another screen load active tab from sandbox
    if active_tab
      @active_tab = active_tab.id.to_s
      @sb[:active_db]    = active_tab.name
      @sb[:active_db_id] = active_tab.id
    end

    records.each do |db|
      @tabs.push([db.id.to_s, db.description])
      # check this only first time when user logs in comes to dashboard show

      next if @sb[:dashboards]
      # get user dashboard version
      ws = MiqWidgetSet.where_unique_on(db.name, current_user).first
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
    ws = MiqWidgetSet.where_unique_on(@sb[:active_db], current_user).first

    # if all of user groups dashboards have been deleted and they are logged in, need to reset active_db_id
    if ws.nil?
      wset = MiqWidgetSet.find_by_id(@sb[:active_db_id])
      @sb[:active_db_id] = nil if wset.nil?
    end

    # Create default dashboard for this user, if not present
    ws = create_user_dashboard(@sb[:active_db_id]) if ws.nil?

    # Set tabs now if user's group didnt have any dashboards using default dashboard
    if records.empty?
      db = MiqWidgetSet.find_by_id(@sb[:active_db_id])
      @active_tab = ws.id.to_s
      @tabs.push([ws.id.to_s, db.description])
    # User's group has dashboards, delete userid|default dashboard if it exists, dont need to keep that
    else
      db = MiqWidgetSet.where_unique_on("default", current_user).first
      db.destroy if db.present?
    end

    @sb[:dashboards][@sb[:active_db]] = ws.set_data
    @sb[:dashboards][@sb[:active_db]][:minimized] ||= [] # Init minimized widgets array

    # Build the available widgets for the pulldown
    col_widgets = @sb[:dashboards][@sb[:active_db]][:col1] +
                  @sb[:dashboards][@sb[:active_db]][:col2] +
                  @sb[:dashboards][@sb[:active_db]][:col3]

    # Build widget_list to load the widget dropdown list toolbar
    widget_list = []
    prev_type   = nil
    @available_widgets = []
    MiqWidget.available_for_user(current_user).sort_by { |a| a.content_type + a.title.downcase }.each do |w|
      @available_widgets.push(w.id)  # Keep track of widgets available to this user
      if !col_widgets.include?(w.id) && w.enabled
        image, tip = case w.content_type
                     when "menu"   then ["fa fa-share-square-o fa-lg",     _("Add this Menu Widget")]
                     when "rss"    then ["fa fa-rss fa-lg",  _("Add this RSS Feed Widget")]
                     when "chart"  then ["product product-chart fa-lg", _("Add this Chart Widget")]
                     when "report" then ["product product-report fa-lg",   _("Add this Report Widget")]
                     end
        if prev_type && prev_type != w.content_type
          widget_list << {:id => w.content_type, :type => :separator}
        end
        prev_type = w.content_type
        widget_list << {
          :id    => w.id,
          :type  => :button,
          :text  => w.title,
          :image => image.to_s,
          :title => tip
        }
      end
    end

    can_add   = role_allows?(:feature => "dashboard_add")
    can_reset = role_allows?(:feature => "dashboard_reset")
    if can_add || can_reset
      @widgets_menu = {}
      if widget_list.blank?
        @widgets_menu[:blank] = true
      else
        @widgets_menu[:allow_add] = can_add
        @widgets_menu[:locked]    = @sb[:dashboards][@sb[:active_db]][:locked] if can_add
        @widgets_menu[:items]     = widget_list
      end
      @widgets_menu[:allow_reset] = can_reset
    end

    # Make widget presenter forget chart data from previous HTTP request handled
    # by this process.
    WidgetPresenter.reset_data
  end

  # Destroy and recreate a user's dashboard from the default
  def reset_widgets
    assert_privileges("dashboard_reset")
    ws = MiqWidgetSet.where_unique_on(@sb[:active_db], current_user).first
    ws.destroy unless ws.nil?
    ws = create_user_dashboard(@sb[:active_db_id])
    @sb[:dashboards] = nil  # Reset dashboards hash so it gets recreated
    javascript_redirect :action => 'show'
  end

  # Toggle dashboard item size
  def widget_toggle_minmax
    unless params[:widget] # Make sure we got a widget in
      head :ok
      return
    end

    w = params[:widget].to_i
    render :update do |page|
      page << javascript_prologue
      if @sb[:dashboards][@sb[:active_db]][:minimized].include?(w)
        page << javascript_show("dd_w#{w}_box")
        page << "$('#w_#{w}_minmax').prop('title', ' Minimize');"
        page << "$('#w_#{w}_minmax').text(' Minimize');"
        page << javascript_prepend_span("w_#{w}_minmax", "fa fa-caret-square-o-up fa-fw")
        @sb[:dashboards][@sb[:active_db]][:minimized].delete(w)
      else
        page << javascript_hide("dd_w#{w}_box")
        page << "$('#w_#{w}_minmax').prop('title', ' Maximize');"
        page << "$('#w_#{w}_minmax').text(' Maximize');"
        page << javascript_prepend_span("w_#{w}_minmax", "fa fa-caret-square-o-down fa-fw")
        @sb[:dashboards][@sb[:active_db]][:minimized].push(w)
      end
    end
    save_user_dashboards
  end

  # Zoom in on chart widget
  def widget_zoom
    unless params[:widget] # Make sure we got a widget in
      head :ok
      return
    end

    widget = MiqWidget.find_by_id(params[:widget].to_i)
    # Save the rr id for render_zgraph
    @sb[:report_result_id] = widget.contents_for_user(current_user).miq_report_result_id

    render :update do |page|
      page << javascript_prologue
      page.replace_html("lightbox_div", :partial => "zoomed_chart", :locals => {:widget => widget})
      page << "$('#lightbox-panel').fadeIn(300);"
      page << "miqLoadCharts();"
    end
  end

  # A widget has been dropped
  def widget_dd_done
    if params[:col1] || params[:col2] || params[:col3]
      if params[:col1] && params[:col1] != [""]
        @sb[:dashboards][@sb[:active_db]][:col1] = params[:col1].collect { |w| w.split("_").last.to_i }
        @sb[:dashboards][@sb[:active_db]][:col2].delete_if { |w| @sb[:dashboards][@sb[:active_db]][:col1].include?(w) }
        @sb[:dashboards][@sb[:active_db]][:col3].delete_if { |w| @sb[:dashboards][@sb[:active_db]][:col1].include?(w) }
      elsif params[:col2] && params[:col2] != [""]
        @sb[:dashboards][@sb[:active_db]][:col2] = params[:col2].collect { |w| w.split("_").last.to_i }
        @sb[:dashboards][@sb[:active_db]][:col1].delete_if { |w| @sb[:dashboards][@sb[:active_db]][:col2].include?(w) }
        @sb[:dashboards][@sb[:active_db]][:col3].delete_if { |w| @sb[:dashboards][@sb[:active_db]][:col2].include?(w) }
      elsif params[:col3] && params[:col3] != [""]
        @sb[:dashboards][@sb[:active_db]][:col3] = params[:col3].collect { |w| w.split("_").last.to_i }
        @sb[:dashboards][@sb[:active_db]][:col1].delete_if { |w| @sb[:dashboards][@sb[:active_db]][:col3].include?(w) }
        @sb[:dashboards][@sb[:active_db]][:col2].delete_if { |w| @sb[:dashboards][@sb[:active_db]][:col3].include?(w) }
      end
      save_user_dashboards
    end
    head :ok               # We have nothing to say  :)
  end

  # A widget has been closed
  def widget_close
    if params[:widget]                # Make sure we got a widget in
      w = params[:widget].to_i
      @sb[:dashboards][@sb[:active_db]][:col1].delete(w)
      @sb[:dashboards][@sb[:active_db]][:col2].delete(w)
      @sb[:dashboards][@sb[:active_db]][:col3].delete(w)
      @sb[:dashboards][@sb[:active_db]][:minimized].delete(w)
      ws = MiqWidgetSet.where_unique_on(@sb[:active_db], current_user).first
      w = MiqWidget.find_by_id(w)
      ws.remove_member(w) if w
      save_user_dashboards
      javascript_redirect :action => 'show'
    else
      head :ok
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
      ws = MiqWidgetSet.where_unique_on(@sb[:active_db], current_user).first
      w = MiqWidget.find_by_id(w)
      if ws.add_member(w).present?
        save_user_dashboards
        w.create_initial_content_for_user(session[:userid])
        javascript_redirect :action => 'show'
      else
        render_flash(_("The widget \"%{widget_name}\" is already part of the edited dashboard") %
         {:widget_name => w.name}, :error)
      end
    else
      head :ok
    end
  end

  # Methods to handle login/authenticate/logout functions
  def login
    if ext_auth?(:saml_enabled) && ext_auth?(:local_login_disabled)
      redirect_to saml_protected_page
      return
    end

    if ::Settings.product.allow_passed_in_credentials # Only pre-populate credentials if setting is turned on
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

    if session[:user_validation_error]
      add_flash(session[:user_validation_error], :error)
      session[:user_validation_error] = nil
    end

    render :layout => "login"
  end

  # AJAX login retry method
  def login_retry
    #     if MiqServer.my_server(true).logon_status == :starting
    logon_details = MiqServer.my_server(true).logon_status_details
    if logon_details[:status] == :starting
      render :update do |page|
        page << javascript_prologue
        @login_message = logon_details[:message] if logon_details[:message]
        page.replace("login_message_div", :partial => "login_message")
        page << "setTimeout(\"#{remote_function(:url => {:action => 'login_retry'})}\", 10000);"
      end
    else
      javascript_redirect :action => 'login'
    end
  end

  # Initiate a SAML Login from the main login page
  def initiate_saml_login
    javascript_redirect saml_protected_page
  end

  # Login support for SAML - GET /saml_login
  def saml_login
    if @user_name.blank? && request.env.key?("HTTP_X_REMOTE_USER").present?
      @user_name = params[:user_name] = request.env["HTTP_X_REMOTE_USER"].split("@").first
    else
      redirect_to :action => 'logout'
      return
    end

    user = {:name => @user_name}
    validation = validate_user(user, nil, request, :require_user => true, :timeout => 30)

    case validation.result
    when :pass
      render :template => "dashboard/saml_login",
             :layout   => false,
             :locals   => {:api_auth_token => generate_ui_api_token(@user_name),
                           :validation_url => validation.url}
      return
    when :fail
      session[:user_validation_error] = validation.flash_msg || "User validation failed"
      redirect_to :action => 'logout'
      return
    end
  end

  # Handle external-auth signon from login screen
  def external_authenticate
    authenticate_external_user_generate_api_token
  end

  # Handle single-signon from login screen
  def kerberos_authenticate
    authenticate_external_user_generate_api_token
  end

  # Handle user credentials from login screen
  def authenticate(require_api_token = false)
    @layout = "dashboard"

    unless params[:task_id] # First time thru, check for buttons pressed
      # Handle More and Back buttons (for changing password)
      case params[:button]
      when "more"
        @more = true
        render :update do |page|
          page << javascript_prologue
          page.replace("login_more_div", :partial => "login_more")
          page << javascript_focus('user_new_password')
          page << javascript_show("back_button")
          page << javascript_hide("more_button")
        end
        return
      when "back"
        render :update do |page|
          page << javascript_prologue
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
       request.headers["X-Remote-User"].blank? &&
       ::Settings.authentication.mode == "httpd" &&
       ::Settings.authentication.sso_enabled &&
       params[:action] == "authenticate"

      javascript_redirect root_path
      return
    end

    validation = validate_user(user, params[:task_id], request)
    case validation.result
    when :wait_for_task
      # noop, page content already set by initiate_wait_for_task
    when :pass
      miq_api_token = require_api_token ? generate_ui_api_token(user[:name]) : nil
      render :update do |page|
        page << javascript_prologue
        page << "sessionStorage.miq_token = '#{j_str miq_api_token}';" if miq_api_token
        page.redirect_to(validation.url)
      end
    when :fail
      clear_current_user
      add_flash(validation.flash_msg || _("Error: Authentication failed"), :error)
      render :update do |page|
        page << javascript_prologue
        page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        page << javascript_show("flash_div")
        page << "miqSparkle(false);"
        page << "miqEnableLoginFields(true);"
      end
    end
  end

  def generate_ui_api_token(userid)
    @api_user_token_service ||= Api::UserTokenService.new
    @api_user_token_service.generate_token(userid, "ui")
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
      drop_breadcrumb(:name => _("Timelines"), :url => "/dashboard/timeline")
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
        page << javascript_prologue
        if @ajax_action
          page << "miqAsyncAjax('#{url_for(:action => @ajax_action, :id => @record)}');"
        end
      end
    else
      @report = nil
      drop_breadcrumb(:name => _("Timelines"), :url => "/dashboard/timeline")
      @timeline = true
      session[:last_rpt_id] = nil # Clear out last rpt record id
      build_timeline_listnav
    end
  end

  # Process changes to timeline selection
  def tl_generate
    # set variables for type of timeline is selected
    unless @timeline
      tl_gen_timeline_data
      return unless @timeline
    end

    @timeline = true
    render :update do |page|
      page << javascript_prologue
      page << javascript_highlight("report_#{session[:last_rpt_id]}_link", false)  if session[:last_rpt_id]
      center_tb_buttons = {
        'timeline_txt' => "text",
        'timeline_csv' => "CSV"
      }
      center_tb_buttons['timeline_pdf'] = "PDF" if PdfGenerator.available?
      # if @report
      #   page << javascript_highlight("report_#{@report.id}_link", true)
      #   status = @report.table.data.length == 0 ? :disabled : :enabled
      #
      #   center_tb_buttons.each do |button_id, typ|
      #     page << "ManageIQ.toolbars.showItem('#center_tb', '#{button_id}');"
      #     page << tl_toggle_button_enablement(button_id, status, typ)
      #   end
      # else
      #   center_tb_buttons.keys.each do |button_id|
      #     page << "ManageIQ.toolbars.hideItem('#center_tb', '#{button_id}');"
      #   end
      # end

      page.replace("tl_div", :partial => "dashboard/tl_detail")
      page << "miqSparkle(false);"
      session[:last_rpt_id] = @report.try(:id)  # Remember rpt record id to turn off later
    end
  end

  def logout
    current_user.try(:logoff)
    clear_current_user

    user_validation_error = session[:user_validation_error]
    session.clear
    session[:auto_login] = false
    session[:user_validation_error] = user_validation_error if user_validation_error

    # For SAML, let's do the SAML logout to clear mod_auth_mellon IdP cookies and such
    if ext_auth?(:saml_enabled)
      redirect_to "/saml2/logout?ReturnTo=/"
    else
      redirect_to :action => 'login'
    end
    return
  end

  # User request to change to a different eligible group
  def change_group
    # Get the user and new group and set current_group in the user record
    db_user = current_user
    db_user.update_attributes(:current_group => MiqGroup.find_by_id(params[:to_group]))

    # Rebuild the session
    session_reset
    session_init(db_user)
    session[:group_changed] = true
    url = start_url_for_user(nil) || url_for(:controller => params[:controller], :action => 'show')
    javascript_redirect url
  end

  # Put out error msg if user's role is not authorized for an action
  def auth_error
    add_flash(_("The user is not authorized for this task or item."), :error)
    add_flash(_("Press your browser's Back button or click a tab to continue"))
  end

  private

  # Authenticate external user and generate API token
  def authenticate_external_user_generate_api_token
    if @user_name.blank? && request.headers["X-Remote-User"].present?
      @user_name = params[:user_name] = request.headers["X-Remote-User"].split("@").first
    end

    authenticate(true)
  end

  def tl_toggle_button_enablement(button_id, enablement, typ)
    if enablement == :enabled
      tooltip = _("Download this Timeline data in %{typ} format") % {:typ => typ}
      "ManageIQ.toolbars.enableItem('#center_tb', '#{button_id}'); ManageIQ.toolbars.setItemTooltip('#center_tb', '#{button_id}', '#{tooltip}');"
    else
      tooltip = _('No records found for this timeline')
      "ManageIQ.toolbars.disableItem('#center_tb', '#{button_id}'); ManageIQ.toolbars.setItemTooltip('#center_tb', '#{button_id}', '#{tooltip}');"
    end
  end
  helper_method(:tl_toggle_button_enablement)

  def validate_user(user, task_id = nil, request = nil, authenticate_options = {})
    UserValidationService.new(self).validate_user(user, task_id, request, authenticate_options)
  end

  def session_reset
    # save some fields to recover back into session hash after session is cleared
    keys_to_restore = [:browser, :user_TZO]
    data_to_restore = keys_to_restore.each_with_object({}) { |k, v| v[k] = session[k] }

    session.clear
    session.update(data_to_restore)

    # Clear instance vars that end up in the session
    @sb = @edit = @view = @settings = @lastaction = @perf_options = @assign = nil
    @current_page = @search_text = @detail_sortcol = @detail_sortdir = @exp_key = nil
    @server_options = @tl_options = @pp_choices = @panels = @breadcrumbs = nil
  end

  # Initialize session hash variables for the logged in user
  def session_init(db_user)
    self.current_user = db_user

    # Load settings for this user, if they exist
    @settings = copy_hash(DEFAULT_SETTINGS)             # Start with defaults
    unless db_user.nil? || db_user.settings.nil?    # If the user has saved settings

      db_user.settings.delete(:dashboard)               # Remove pre-v4 dashboard settings
      db_user.settings.delete(:db_item_min)

      @settings.each { |key, value| value.merge!(db_user.settings[key]) unless db_user.settings[key].nil? }
      @settings[:default_search] = db_user.settings[:default_search]  # Get the user's default search setting
    end

    # Copy ALL display settings into the :css hash so we can easily add new settings
    @settings[:css] ||= {}
    @settings[:css].merge!(@settings[:display])
    @settings[:display][:theme] = THEMES.first.last unless THEMES.collect(&:last).include?(@settings[:display][:theme])
    @settings[:css].merge!(THEME_CSS_SETTINGS[@settings[:display][:theme]])

    @css ||= {}
    @css.merge!(@settings[:display])
    @css.merge!(THEME_CSS_SETTINGS[@settings[:display][:theme]])

    session[:user_TZO] = params[:user_TZO] ? params[:user_TZO].to_i : nil     # Grab the timezone (future use)
    session[:browser] ||= Hash.new("Unknown")
    if params[:browser_name]
      session[:browser][:name] = params[:browser_name].to_s.downcase
      session[:browser][:name_ui] = params[:browser_name]
    end
    session[:browser][:version] = params[:browser_version] if params[:browser_version]
    if params[:browser_os]
      session[:browser][:os] = params[:browser_os].to_s.downcase
      session[:browser][:os_ui] = params[:browser_os]
    end
  end

  # Create a user's dashboard, pass in dashboard id if that is used to copy else use default dashboard
  def create_user_dashboard(db_id = nil)
    db = db_id ? MiqWidgetSet.find_by_id(db_id) : MiqWidgetSet.where_unique_on("default").first
    ws = MiqWidgetSet.where_unique_on(db.name, current_user).first
    if ws.nil?
      # Create new db if it doesn't exist
      ws = MiqWidgetSet.new(:name        => db.name,
                            :group_id    => current_group_id,
                            :userid      => current_userid,
                            :description => _("%{name} dashboard for user %{id} in group id %{current_group_id}") %
                                              {:name             => db.name,
                                               :id               => current_userid,
                                               :current_group_id => current_group_id})
      ws.set_data = db.set_data
      ws.set_data[:last_group_db_updated] = db.updated_on
      ws.save!
      ws.replace_children(db.children)
      ws.members.each { |w| w.create_initial_content_for_user(session[:userid]) }  # Generate content if not there
    end
    unless db_id     # set active_db and id and tabs now if user's group didnt have any dashboards
      @sb[:active_db] = db.name
      @sb[:active_db_id] = db.id
    end
    ws
  end

  # Save dashboards for user
  def save_user_dashboards
    ws = MiqWidgetSet.where_unique_on(@sb[:active_db], current_user).first
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
    @timeline = true unless @report # need to set this incase @report is not there, when switching between Management/Policy events
    return unless @report

    unless params[:task_id] # First time thru, kick off the report generate task
      initiate_wait_for_task(:task_id => @report.async_generate_table(:userid => session[:userid]))
      return
    end

    @timeline = true
    miq_task = MiqTask.find(params[:task_id]) # Not first time, read the task record
    @report  = miq_task.task_results
    session[:rpt_task_id] = miq_task.id
    unless miq_task.results_ready?
      add_flash(_("Error building timeline  %{error_message}") % {:error_message => miq_task.message}, :error)
      return
    end

    @timeline = true
    if @report.table.data.empty?
      add_flash(_("No records found for this timeline"), :warning)
      return
    end

    @report.extras[:browser_name] = browser_info(:name)
    if is_browser_ie?
      blob = BinaryBlob.new(:name => "timeline_results")
      blob.binary = @report.to_timeline
      session[:tl_xml_blob_id] = blob.id
    else
      @tl_json = @report.to_timeline
    end

    tz = @report.tz || Time.zone
    session[:tl_position] = format_timezone(@report.extras[:tl_position], tz, "tl")
  end

  def get_session_data
    @layout       = "login"
    @current_page = session[:vm_current_page] # current page number
  end

  def set_session_data
    session[:layout]          = @layout
    session[:vm_current_page] = @current_page
  end
end
