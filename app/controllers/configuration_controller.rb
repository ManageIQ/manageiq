require 'miq_bulk_import'
class ConfigurationController < ApplicationController
  logo_dir = File.expand_path(File.join(Rails.root, "public/upload"))
  Dir.mkdir logo_dir unless File.exist?(logo_dir)
  @@logo_file = File.join(logo_dir, "custom_logo.png")

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  include_concern 'TimeProfile'

  def index
    @breadcrumbs = []
    @config_tab = params[:config_tab] ? params[:config_tab] : "ui"
    active_tab = nil
    if role_allows(:feature => "my_settings_visuals")
      active_tab = 1 if active_tab.nil?
    elsif role_allows(:feature => "my_settings_default_views")
      active_tab = 2 if active_tab.nil?
    elsif role_allows(:feature => "my_settings_default_filters")
      active_tab = 3 if active_tab.nil?
    elsif role_allows(:feature => "my_settings_time_profiles")
      active_tab = 4 if active_tab.nil?
    end
    @tabform = params[:load_edit_err] ? @tabform : @config_tab + "_#{active_tab}"
    case @config_tab
    when "operations", "ui", "filters"
      if @tabform == "operations_1" || @tabform == "operations_2"
        init_server_options
        @server_options[:server_id] = MiqServer.my_server.id
        @server_options[:remote] = false
      end
      if (@tabform == "filters_1")
        @tabform = @config_tab + "_2"
      end
      if (@tabform == "filters_2")
        @tabform = @config_tab + "_3"
      end
      edit
    when "admin"
      show_users
    end
    render :action => "show"
  end

  # handle buttons pressed on the button bar
  def button
    @refresh_div = "main_div" # Default div for button.rjs to refresh
    timeprofile_button

    if ! @refresh_partial && @flash_array.nil? # if no button handler ran, show not implemented msg
      add_flash(_("Button not yet implemented"), :error)
      @refresh_partial = "layouts/flash_msg"
      @refresh_div = "flash_msg_div"
    end

    if params[:pressed].ends_with?("_edit", "_copy")
      render :update do |page|
        page << javascript_prologue
        page.redirect_to :action => @refresh_partial, :id => @redirect_id
      end
    else
      c_tb = build_toolbar(center_toolbar_filename)
      render :update do |page|
        page << javascript_prologue
        page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        page.replace_html("main_div", :partial => "ui_4") # Replace the main div area contents
        page << javascript_pf_toolbar_reload('center_tb', c_tb)
      end
    end
  end

  def edit
    set_form_vars   # Go fetch the settings into the object for the form
    session[:changed] = @changed = false
    build_tabs
  end

  # New tab was pressed
  def change_tab
    @tabform = @config_tab + "_" + params[:tab] if params[:tab] != "5"
    edit
    render :action => "show"
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def form_field_changed
    # ui1 edit form
    return unless load_edit("config_edit__ui1", "configuration")
    get_form_vars
    @assigned_filters = []
    @changed = (@edit[:new] != @edit[:current])
    render :update do |page|
      page << javascript_prologue
      page.replace(@refresh_div, :partial => @refresh_partial) if @refresh_div
      page << javascript_for_miq_button_visibility_changed(@changed)
    end
  end

  # AJAX driven routine to check for changes in ANY field on the user form
  def filters_field_changed
    return unless load_edit("config_edit__ui3", "configuration")
    id = params[:id].split('-').last.to_i
    @edit[:new].find { |x| x[:id] == id }[:search_key] = params[:check] == 'true' ? nil : '_hidden_'
    @edit[:current].each_with_index do |arr, i|          # needed to compare each array element's attributes to find out if something has changed
      if @edit[:new][i][:search_key] != arr[:search_key]
        @changed = true
        break
      end
    end
    @changed = false unless @changed
    render :update do |page|
      page << javascript_prologue
      @edit[:current].each_with_index do |filter, i|
        style_class = if filter[:search_key] != @edit[:new][i][:search_key]
                        'cfme-blue-bold-node'
                      else
                        'dynatree-title'
        end
        page << "miqDynatreeNodeAddClass('df_tree', $('[id$=\"-#{filter[:id]}\"]'), '#{style_class}')"
      end
      page << javascript_for_miq_button_visibility(@changed)
    end
  end

  # AJAX driven routine for gtl view selection
  def view_selected
    # ui2 form
    return unless load_edit("config_edit__ui2", "configuration")
    @edit[:new][:views][VIEW_RESOURCES[params[:resource]]] = params[:view] # Capture the new view setting
    session[:changed] = (@edit[:new] != @edit[:current])
    @changed = session[:changed]
    render :update do |page|
      page << javascript_prologue
      page.replace 'tab_div', :partial => "ui_2"
    end
  end

  # AJAX driven routine for theme selection
  def theme_changed
    # ui1 theme changed
    @edit = session[:edit]
    @edit[:new][:display][:theme] = params[:theme]      # Capture the new setting
    session[:changed] = (@edit[:new] != @edit[:current])
    @changed = session[:changed]
    render :update do |page|
      page << javascript_prologue
      page.replace 'tab_div', :partial => "ui_1"
    end
  end

  # AJAX driven routine for nav style selection
  def nav_style_changed
    @edit = session[:edit]
    @edit[:new][:display][:nav_style] = params[:nav_style]    # Capture the new setting
    session[:changed] = (@edit[:new] != @edit[:current])
    @changed = session[:changed]
    render :update do |page|
      page << javascript_prologue
      page.replace 'tab_div', :partial => "ui_1"
    end
  end

  # AJAX driven routine for background color selection
  def bg_color_changed
    # ui1 bgcolor changed
    @edit = session[:edit]
    @edit[:new][:display][:bg_color] = params[:bg_color]      # Capture the new setting
    session[:changed] = (@edit[:new] != @edit[:current])
    @changed = session[:changed]
    render :update do |page|
      page << javascript_prologue
      page.replace 'tab_div', :partial => "ui_1"
    end
  end

  def update
    if params["save"]
      get_form_vars if @tabform != "ui_3"
      case @tabform
      when "ui_1"                                                 # Visual tab
        @settings.merge!(@edit[:new])                                   # Apply the new saved settings

        if current_user
          user_settings = merge_settings(current_user.settings, @settings)
          current_user.update_attributes(:settings => user_settings)

          # Now copying ALL display settings into the :css hash so we can easily add new settings
          @settings[:css] ||= {}
          @settings[:css].merge!(@settings[:display])
          @settings[:css].merge!(THEME_CSS_SETTINGS[@settings[:display][:theme]])

          @css ||= {}
          @css.merge!(@settings[:display])
          @css.merge!(THEME_CSS_SETTINGS[@settings[:display][:theme]])
          set_user_time_zone
          add_flash(_("User Interface settings saved for User %{name}") % {:name => current_user.name})
        else
          add_flash(_("User Interface settings saved for this session"))
        end
        edit
        render :action => "show"
        return                                                    # No config file for Visuals yet, just return
      when "ui_2"                                                 # Visual tab
        @settings.merge!(@edit[:new])                                   # Apply the new saved settings
        prune_old_settings(@settings)
        if current_user
          settings = merge_settings(current_user.settings, @settings)
          current_user.update_attributes(:settings => settings)
          add_flash(_("User Interface settings saved for User %{name}") % {:name => current_user.name})
        else
          add_flash(_("User Interface settings saved for this session"))
        end
        edit
        render :action => "show"
        return                                                      # No config file for Visuals yet, just return
      when "ui_3"                                                   # User Filters tab
        @edit = session[:edit]
        @edit[:new].each do |filter|
          search = MiqSearch.find(filter[:id])
          search.update(:search_key => filter[:search_key]) unless search.search_key == filter[:search_key]
        end
        add_flash(_("Default Filters saved successfully"))
        edit
        render :action => "show"
        return # No config file for Visuals yet, just return
      end
    elsif params["reset"]
      edit
      add_flash(_("All changes have been reset"), :warning)
      render :action => "show"
    end
  end

  def show
    show_timeprofiles if params[:typ] == "timeprofiles"
  end

  private ############################

  def build_tabs
    @breadcrumbs = []
    case @config_tab
    when "ui"
      @tabs = []
      if @tabform != "ui_4"
        drop_breadcrumb({:name => _("User Interface Configuration"), :url => "/configuration/edit"}, true)
      end

      # Start with first tab array entry set to tab N as active
      case @tabform
      when "ui_1"
        @tabs[0] = ["1", ""]
      when "ui_2"
        @tabs[0] = ["2", ""]
      when "ui_3"
        @tabs[0] = ["3", ""]
      when "ui_4"
        @tabs[0] = ["4", ""]
      end

      @tabs.push(["1", _("Visual")])          if role_allows(:feature => "my_settings_visuals")
      @tabs.push(["2", _("Default Views")])   if role_allows(:feature => "my_settings_default_views")
      @tabs.push(["3", _("Default Filters")]) if role_allows(:feature => "my_settings_default_filters")
      @tabs.push(["4", _("Time Profiles")])   if role_allows(:feature => "my_settings_time_profiles")
    end
  end

  def merge_in_user_settings(settings)
    if user_settings = current_user.try(:settings)
      settings.each do |key, value|
        value.merge!(user_settings[key]) unless user_settings[key].nil?
      end
    end
    settings
  end

  # * start with DEFAULT_SETTINGS
  # * merge in current session changes
  # * merge in any settings from the DB if they exist
  def init_settings
    merge_in_user_settings(copy_hash(DEFAULT_SETTINGS))
  end

  def set_form_vars
    case @tabform
    when 'ui_1'
      @edit = {
        :current => init_settings,
        :key     => 'config_edit__ui1',
      }

      current_tz = @edit.fetch_path(:current, :display, :timezone)
      if current_tz.blank?
        new_tz = MiqServer.my_server.get_config("vmdb").config[:server][:timezone]
        new_tz = 'UTC' if new_tz.blank?
        @edit.store_path(:current, :display, :timezone, new_tz)
      end

      # Build the start pages pulldown list
      session[:start_pages] = MiqShortcut.start_pages.each_with_object([]) do |page, pages|
        pages.push([page[1], page[0]]) if start_page_allowed?(page[2])
      end
    when 'ui_2'
      @edit = {
        :current => init_settings,
        :key     => 'config_edit__ui2',
      }
    when 'ui_3'
      filters = MiqSearch.where(:search_type => "default")
      current = filters.map do |filter|
        {:id => filter.id, :search_key => filter.search_key}
      end
      @edit = {
        :key         => 'config_edit__ui3',
        :set_filters => true,
        :current     => current,
      }
      @df_tree = TreeBuilderDefaultFilters.new(:df_tree, :df, @sb, true, filters)
      self.x_active_tree = :df_tree
    when 'ui_4'
      timeprofile_set_form_vars
    end
    @edit[:new] = copy_hash(@edit[:current])
    session[:edit] = @edit
  end

  def get_form_vars
    @edit = session[:edit]
    case @tabform
    when "ui_1"                                               # Visual Settings tab
      @edit[:new][:quadicons][:ems] = params[:quadicons_ems] == "true" if params[:quadicons_ems]
      @edit[:new][:quadicons][:ems_cloud] = params[:quadicons_ems_cloud] == "true" if params[:quadicons_ems_cloud]
      @edit[:new][:quadicons][:host] = params[:quadicons_host] == "true" if params[:quadicons_host]
      @edit[:new][:quadicons][:vm] = params[:quadicons_vm] == "true" if params[:quadicons_vm]
      @edit[:new][:quadicons][:miq_template] = params[:quadicons_miq_template] == "true" if params[:quadicons_miq_template]
      if get_vmdb_config[:product][:proto] # Hide behind proto setting - Sprint 34
        @edit[:new][:quadicons][:service] = params[:quadicons_service] == "true" if params[:quadicons_service]
      end
      @edit[:new][:quadicons][:storage] = params[:quadicons_storage] == "true" if params[:quadicons_storage]
      @edit[:new][:perpage][:grid] = params[:perpage_grid].to_i if params[:perpage_grid]
      @edit[:new][:perpage][:tile] = params[:perpage_tile].to_i if params[:perpage_tile]
      @edit[:new][:perpage][:list] = params[:perpage_list].to_i if params[:perpage_list]
      @edit[:new][:perpage][:reports] = params[:perpage_reports].to_i if params[:perpage_reports]
      @edit[:new][:display][:theme] = params[:display_theme] unless params[:display_theme].nil?
      @edit[:new][:display][:bg_color] = params[:bg_color] unless params[:bg_color].nil?
      @edit[:new][:display][:reporttheme] = params[:display_reporttheme] unless params[:display_reporttheme].nil?
      @edit[:new][:display][:dashboards] = params[:display_dashboards] unless params[:display_dashboards].nil?
      @edit[:new][:display][:timezone] = params[:display_timezone] unless params[:display_timezone].nil?
      @edit[:new][:display][:startpage] = params[:start_page] unless params[:start_page].nil?
      @edit[:new][:display][:quad_truncate] = params[:quad_truncate] unless params[:quad_truncate].nil?
      @edit[:new][:display][:locale] = params[:display_locale] if params[:display_locale]
    when "ui_2", "ui_3", "ui_4" # Default Views, Default Filters, Time Profiles
      # nothing, uses different code
    end
  end

  def get_session_data
    @title        = session[:config_title] ? _("Configuration") : session[:config_title]
    @layout       = "configuration"
    @config_tab   = session[:config_tab]        if session[:config_tab]
    @tabform      = session[:config_tabform]    if session[:config_tabform]
    @schema_ver   = session[:config_schema_ver] if session[:config_schema_ver]
    @zone_options = session[:zone_options]      if session[:zone_options]
  end

  def set_session_data
    session[:config_tab]        = @config_tab
    session[:config_tabform]    = @tabform
    session[:config_schema_ver] = @schema_ver
    session[:vm_filters]        = @filters
    session[:vm_catinfo]        = @catinfo
    session[:vm_cats]           = @cats
    session[:zone_options]      = @zone_options
  end

  def merge_settings(user_settings, global_settings)
    prune_old_settings(user_settings ? user_settings.merge(global_settings) : global_settings)
  end

  # typically passing in session, but sometimes passing in @session
  def prune_old_settings(s)
    # ui_1
    s[:display].delete(:pres_mode)          # :pres_mode replaced by :theme
    s.delete(:css)                          # Moved this to @css
    s.delete(:adv_search)                   # These got in around sprint 40 by accident

    # ui_2
    s[:display].delete(:vmcompare)          # :vmcompare moved to :views hash
    s[:display].delete(:vm_summary_cool)    # :vm_summary_cool moved to :views hash
    s[:views].delete(:vm_summary_cool)      # :views/:vm_summary_cool changed to :dashboards
    s[:views].delete(:dashboards)           # :dashboards is obsolete now

    s
  end
end
