require 'miq_bulk_import'
class ConfigurationController < ApplicationController
  logo_dir = File.expand_path(File.join(Rails.root, "public/upload"))
  Dir.mkdir logo_dir unless File.exist?(logo_dir)
  @@logo_file = File.join(logo_dir, "custom_logo.png")

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def index
    @breadcrumbs = []
    @config_tab = params[:config_tab] ? params[:config_tab] : "ui"
    active_tab = nil
    if role_allows?(:feature => "my_settings_visuals")
      active_tab = 1 if active_tab.nil?
    elsif role_allows?(:feature => "my_settings_default_views")
      active_tab = 2 if active_tab.nil?
    elsif role_allows?(:feature => "my_settings_default_filters")
      active_tab = 3 if active_tab.nil?
    elsif role_allows?(:feature => "my_settings_time_profiles")
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
    timeprofile_delete if params[:pressed] == "tp_delete"
    copy_record if params[:pressed] == "tp_copy"
    edit_record if params[:pressed] == "tp_edit"

    if ! @refresh_partial && @flash_array.nil? # if no button handler ran, show not implemented msg
      add_flash(_("Button not yet implemented"), :error)
      @refresh_partial = "layouts/flash_msg"
      @refresh_div = "flash_msg_div"
    end

    if params[:pressed].ends_with?("_edit", "_copy")
      javascript_redirect :action => @refresh_partial, :id => @redirect_id
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
      page << javascript_for_miq_button_visibility(@changed)
    end
  end

  # AJAX driven routine for gtl view selection
  def view_selected
    # ui2 form
    return unless load_edit("config_edit__ui2", "configuration")
    @edit[:new][:views][VIEW_RESOURCES[params[:resource]]] = params[:view] # Capture the new view setting
    @edit[:new][:display][:display_vms] = params[:display_vms] == 'true' if params.key?(:display_vms)
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

  # Show the users list
  def show_timeprofiles
    build_tabs if params[:action] == "change_tab" || ["cancel", "add", "save"].include?(params[:button])
    if admin_user?
      @timeprofiles = TimeProfile.in_my_region.ordered_by_desc
    else
      @timeprofiles = TimeProfile.in_my_region.for_user(session[:userid]).ordered_by_desc
    end
    timeprofile_set_days_hours
    drop_breadcrumb(:name => _("Time Profiles"), :url => "/configuration/change_tab/?tab=4")
  end

  def timeprofile_set_days_hours(_timeprofile = @timeprofile)
    @timeprofile_details = {}
    @timeprofiles.each do |timeprofile|
      @timeprofile_details[timeprofile.description] = {}
      @timeprofile_details[timeprofile.description][:days] =
        timeprofile.profile[:days].collect { |day| DateTime::ABBR_DAYNAMES[day.to_i] }
      @timeprofile_details[timeprofile.description][:hours] = []
      temp_arr = timeprofile.profile[:hours].collect(&:to_i).sort
      st = ""
      temp_arr.each_with_index do |hr, i|
        if hr.to_i + 1 == temp_arr[i + 1]
          st = "#{get_hr_str(hr).split('-').first}-" if st == ""
        else
          if st != ""
            @timeprofile_details[timeprofile.description][:hours].push(st + get_hr_str(hr).split('-').last)
          else
            @timeprofile_details[timeprofile.description][:hours].push(get_hr_str(hr))
          end
          st = ""
        end
      end
      if @timeprofile_details[timeprofile.description][:hours].length > 1 && @timeprofile_details[timeprofile.description][:hours].first.split('-').first == "12AM" && @timeprofile_details[timeprofile.description][:hours].last.split('-').last == "12AM"      # manipulating midnight hours to be displayed on show screen
        @timeprofile_details[timeprofile.description][:hours][0] = @timeprofile_details[timeprofile.description][:hours].last.split('-').first + '-' + @timeprofile_details[timeprofile.description][:hours].first.split('-').last
        @timeprofile_details[timeprofile.description][:hours].delete_at(@timeprofile_details[timeprofile.description][:hours].length - 1)
      end
      @timeprofile_details[timeprofile.description][:tz] = timeprofile.profile[:tz]
    end
  end

  def get_hr_str(hr)
    hours = (1..12).to_a
    hour = hr.to_i
    case hour
    when 0..10  then from = to = "AM"
    when 11     then from, to = ["AM", "PM"]
    when 12..22 then from = to = "PM"
    else             from, to = ["PM", "AM"]
    end
    hour = hour >= 12 ? hour - 12 : hour
    "#{hours[hour - 1]}#{from}-#{hours[hour]}#{to}"
  end

  def timeprofile_new
    assert_privileges("timeprofile_new")
    @timeprofile = TimeProfile.new
    set_form_vars
    @in_a_form = true
    @breadcrumbs = []
    drop_breadcrumb(:name => _("Add new Time Profile"), :url => "/configuration/timeprofile_edit")
    render :action => "timeprofile_edit"
  end

  def timeprofile_edit
    assert_privileges("tp_edit")
    @timeprofile = TimeProfile.find(params[:id])
    set_form_vars
    @tp_restricted = true if @timeprofile.profile_type == "global" && !admin_user?
    title = (@timeprofile.profile_type == "global" && !admin_user?) ? _("Time Profile") : _("Edit")
    add_flash(_("Global Time Profile cannot be edited")) if @timeprofile.profile_type == "global" && !admin_user?
    session[:changed] = false
    @in_a_form = true
    drop_breadcrumb(:name => _("%{title} '%{description}'") % {:title       => title,
                                                               :description => @timeprofile.description},
                    :url  => "/configuration/timeprofile_edit")
  end

  # Delete all selected or single displayed VM(s)
  def timeprofile_delete
    assert_privileges("tp_delete")
    timeprofiles = []
    unless params[:id] # showing a list, scan all selected timeprofiles
      timeprofiles = find_checked_items
      if timeprofiles.empty?
        add_flash(_("No %{records} were selected for deletion") %
          {:records => ui_lookup(:models => "TimeProfile")}, :error)
      else
        selected_timeprofiles = TimeProfile.where(:id => timeprofiles)
        selected_timeprofiles.each do |tp|
          if tp.description == "UTC"
            timeprofiles.delete(tp.id.to_s)
            add_flash(_("Default %{model} \"%{name}\" cannot be deleted") % {:model => ui_lookup(:model => "TimeProfile"), :name  => tp.description},
                      :error)
          elsif tp.profile_type == "global" && !admin_user?
            timeprofiles.delete(tp.id.to_s)
            add_flash(_("\"%{name}\": Global %{model} cannot be deleted") % {:name  => tp.description, :model => ui_lookup(:models => "TimeProfile")},
                      :error)
          elsif !tp.miq_reports.empty?
            timeprofiles.delete(tp.id.to_s)
            add_flash(n_("\"%{name}\": In use by %{rep_count} Report, cannot be deleted",
                         "\"%{name}\": In use by %{rep_count} Reports, cannot be deleted",
                         tp.miq_reports.count) % {:name => tp.description, :rep_count => tp.miq_reports.count}, :error)
          end
        end
      end
      process_timeprofiles(timeprofiles, "destroy") unless timeprofiles.empty?
    end
    set_form_vars
  end

  def timeprofile_field_changed
    return unless load_edit("config_edit__ui4", "configuration")
    timeprofile_get_form_vars
    changed = (@edit[:new] != @edit[:current])
    render :update do |page|
      page << javascript_prologue
      page.replace('timeprofile_days_hours_div',
                   :partial => "timeprofile_days_hours",
                   :locals  => {:disabled => false}) if @redraw
      if params.key?(:profile_tz) && admin_user?
        if params[:profile_tz].blank?
          page << javascript_hide("rollup_daily_tr")
        else
          page << javascript_show("rollup_daily_tr")
        end
      end
      if changed != session[:changed]
        session[:changed] = changed
        page << javascript_for_miq_button_visibility(changed)
      end
    end
  end

  def timeprofile_copy
    assert_privileges("tp_copy")
    session[:set_copy] = "copy"
    @in_a_form = true
    timeprofile = TimeProfile.find(params[:id])
    @timeprofile = TimeProfile.new
    @timeprofile.description = _("Copy of %{description}") % {:description => timeprofile.description}
    @timeprofile.profile_type = "user"
    @timeprofile.profile_key = timeprofile.profile_key
    unless timeprofile.profile.nil?
      @timeprofile.profile ||= {}
      @timeprofile.profile[:days] = timeprofile.profile[:days] if timeprofile.profile[:days]
      @timeprofile.profile[:hours] = timeprofile.profile[:hours] if timeprofile.profile[:hours]
      @timeprofile.profile[:tz] = timeprofile.profile[:tz] if timeprofile.profile[:tz]
    end
    set_form_vars
    session[:changed] = false
    drop_breadcrumb(:name => _("Adding copy of '%{description}'") % {:description => @timeprofile.description},
                    :url  => "/configuration/timeprofile_edit")
    render :action => "timeprofile_edit"
  end

  def show
    show_timeprofiles if params[:typ] == "timeprofiles"
  end

  def timeprofile_update
    assert_privileges("tp_edit")

    if params[:id] != "new"
      @timeprofile = TimeProfile.find(params[:id])
    else
      @timeprofile = TimeProfile.new
    end
    if params[:button] == "cancel"
      add_flash(_("Edit of %{model} \"%{name}\" was cancelled by the user") % {:model => ui_lookup(:model => "TimeProfile"), :name => @timeprofile.description})
      params[:id] = @timeprofile.id.to_s
      session[:flash_msgs] = @flash_array.dup                 # Put msgs in session for next transaction
      javascript_redirect :action => 'change_tab', :typ => "timeprofiles", :tab => 4, :id => @timeprofile.id.to_s
    elsif params[:button] == "save"
      params[:all_days] ? days = (0..6).to_a : days = params[:days] ? params[:days].collect{|i| i.to_i} : []
      params[:all_hours] ? hours = (0..23).to_a : hours = params[:hours] ? params[:hours].collect{|i| i.to_i} : []
      @timeprofile.description = params[:description]
      @timeprofile.profile_key = params[:profile_type] == "user" ? session[:userid] : nil
      @timeprofile.profile_type = params[:profile_type]
      @timeprofile.profile = {
          :days => days,
          :hours => hours,
          :tz => params[:profile_tz] == "" ? nil : params[:profile_tz]
      }
      @timeprofile.rollup_daily_metrics = params[:rollup_daily]
      begin
        @timeprofile.save!
      rescue => bang
        add_flash(_("TimeProfile \"%{name}\": Error during 'save': %{error_message}") %
                      {:name => @timeprofile.description, :error_message => bang.message}, :error)
        @in_a_form = true
        drop_breadcrumb(:name => _("Edit '%{description}'") % {:description => @timeprofile.description},
                        :url  => "/configuration/timeprofile_edit")
        javascript_flash
      else
        construct_edit_for_audit(@timeprofile)
        AuditEvent.success(build_created_audit(@timeprofile, @edit))
        add_flash(_("%{model} \"%{name}\" was saved") % {:model => ui_lookup(:model => "TimeProfile"),
                                                         :name  => @timeprofile.description})
        session[:flash_msgs] = @flash_array.dup                 # Put msgs in session for next transaction
        javascript_redirect :action => 'change_tab', :typ => "timeprofiles", :tab => 4, :id => @timeprofile.id.to_s
      end
    end
  end

  def construct_edit_for_audit(timeprofile)
    @edit ||= {}
    @edit[:current] = {
        :description          => timeprofile.description,
        :profile_key          => timeprofile.profile_key,
        :profile_type         => timeprofile.profile_type,
        :profile              => timeprofile.profile,
        :rollup_daily_metrics => timeprofile.rollup_daily_metrics
    }
    days = params[:days] ? params[:days].collect{|i| i.to_i} : []
    hours = params[:hours] ? params[:hours].collect{|i| i.to_i} : []
    @edit[:new] = {
        :description          => params[:description],
        :profile_key          => params[:profile_type] == "user" ? session[:userid] : nil,
        :profile_type         => params[:profile_type],
        :profile              => {:days  => days,
                                  :hours => hours,
                                  :tz    => params[:profile_tz] == "" ? nil : params[:profile_tz]},
        :rollup_daily_metrics => params[:rollup_daily]
    }
  end

  def time_profile_form_fields
    assert_privileges("tp_edit")
    @timeprofile = TimeProfile.new if params[:id] == 'new'
    @timeprofile = TimeProfile.find(params[:id]) if params[:id] != 'new'

    render :json => {:description             => @timeprofile.description,
                     :admin_user              => admin_user?,
                     :restricted_time_profile => @timeprofile.profile_type == "global" && !admin_user?,
                     :profile_type            => @timeprofile.profile_type || "user",
                     :profile_tz              => @timeprofile.tz.nil? ? "" : @timeprofile.tz,
                     :rollup_daily            => !@timeprofile.rollup_daily_metrics.nil?,
                     :all_days                => Array(@timeprofile.days).size == 7,
                     :days                    => Array(@timeprofile.days).uniq.sort,
                     :all_hours               => Array(@timeprofile.hours).size == 24,
                     :hours                   => Array(@timeprofile.hours).uniq.sort,
                     :miq_reports_count       => @timeprofile.miq_reports.count
    }
  end

  private ############################

  # copy single selected Object
  def edit_record
    obj = find_checked_items
    @refresh_partial = "timeprofile_edit"
    @redirect_id = obj[0]
  end

  # copy single selected Object
  def copy_record
    obj = find_checked_items
    @refresh_partial = "timeprofile_copy"
    @redirect_id = obj[0]
  end

  def build_tabs
    @breadcrumbs = []
    if @config_tab == "ui"
      if @tabform != "ui_4"
        drop_breadcrumb({:name => _("User Interface Configuration"), :url => "/configuration/edit"}, true)
      end

      @active_tab = @tabform.split("_").last

      @tabs = []
      @tabs.push(["1", _("Visual")])          if role_allows?(:feature => "my_settings_visuals")
      @tabs.push(["2", _("Default Views")])   if role_allows?(:feature => "my_settings_default_views")
      @tabs.push(["3", _("Default Filters")]) if role_allows?(:feature => "my_settings_default_filters")
      @tabs.push(["4", _("Time Profiles")])   if role_allows?(:feature => "my_settings_time_profiles")
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
      @edit = {
        :current     => {},
        :key         => 'config_edit__ui4',
      }
      @edit[:timeprofile_id] = @timeprofile.try(:id)
      if ['timeprofile_new',  'timeprofile_copy',
          'timeprofile_edit', 'timeprofile_update'].include?(params[:action])
        @edit[:current] = {
          :description  => @timeprofile.description,
          :profile_type => @timeprofile.profile_type || "user",
          :profile_key  => @timeprofile.profile_key,
          :profile      => {
            :days  => Array(@timeprofile.days).uniq.sort,
            :hours => Array(@timeprofile.hours).uniq.sort,
            :tz    => @timeprofile.tz,
          },
          :rollup_daily => @timeprofile.rollup_daily_metrics,
        }
        @edit[:all_days]  = @edit.fetch_path(:current, :profile, :days).length == 7
        @edit[:all_hours] = @edit.fetch_path(:current, :profile, :hours).length == 24
      end
      show_timeprofiles
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
    when "ui_2"                                               # Visual Settings tab
      @edit[:new][:display][:compare] = params[:display][:compare] if !params[:display].nil? && !params[:display][:compare].nil?
      @edit[:new][:display][:drift] = params[:display][:drift] if !params[:display].nil? && !params[:display][:drift].nil?
      @edit[:new][:display][:display_vms] = params[:display_vms] unless params.fetch_path(:display_vms)
    when "ui_3"                                               # Visual Settings tab
      @edit[:new][:display][:compare] = params[:display][:compare] if !params[:display].nil? && !params[:display][:compare].nil?
      @edit[:new][:display][:drift] = params[:display][:drift] if !params[:display].nil? && !params[:display][:drift].nil?
    when "ui_4"                                               # Visual Settings tab
      @edit[:new][:display][:compare] = params[:display][:compare] if !params[:display].nil? && !params[:display][:compare].nil?
      @edit[:new][:display][:drift] = params[:display][:drift] if !params[:display].nil? && !params[:display][:drift].nil?
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

  menu_section :set
end
