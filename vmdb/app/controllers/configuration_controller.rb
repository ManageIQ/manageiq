require 'miq_bulk_import'
class ConfigurationController < ApplicationController
  logo_dir = File.expand_path(File.join(Rails.root, "public/upload"))
  Dir.mkdir logo_dir unless File.exist?(logo_dir)
  @@logo_file = File.join(logo_dir, "custom_logo.png")

  before_filter :check_privileges
  before_filter :get_session_data
  after_filter :cleanup_action
  after_filter :set_session_data

  def index
    @breadcrumbs = Array.new
    @config_tab = params[:config_tab] ? params[:config_tab] : "ui"
    active_tab = nil
    if role_allows(:feature=>"my_settings_visuals")
      active_tab = 1 if active_tab.nil?
    elsif role_allows(:feature=>"my_settings_default_views")
      active_tab = 2 if active_tab.nil?
    elsif role_allows(:feature=>"my_settings_default_filters")
      active_tab = 3 if active_tab.nil?
    elsif role_allows(:feature=>"my_settings_time_profiles")
      active_tab = 4 if active_tab.nil?
    elsif role_allows(:feature=>"my_settings_my_tags")
      if false
        active_tab = 5 if active_tab.nil?
      end
    end
    @tabform = params[:load_edit_err] ? @tabform : @config_tab + "_#{active_tab}"
    case @config_tab
    when "operations", "ui", "filters", "smartproxies"
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
    render :action=>"show"
  end

  # handle buttons pressed on the button bar
  def button
    @refresh_div = "main_div" # Default div for button.rjs to refresh
    timeprofile_delete if params[:pressed] == "tp_delete"
    copy_record if params[:pressed] == "tp_copy"
    edit_record if params[:pressed] == "tp_edit"

    if ! @refresh_partial && @flash_array == nil # if no button handler ran, show not implemented msg
      add_flash(_("Button not yet implemented"), :error)
      @refresh_partial = "layouts/flash_msg"
      @refresh_div = "flash_msg_div"
    end

    if params[:pressed].ends_with?("_edit") || params[:pressed].ends_with?("_copy")
      render :update do |page|
        page.redirect_to :action=>@refresh_partial, :id=>@redirect_id
      end
    else
      c_buttons, c_xml = build_toolbar_buttons_and_xml(center_toolbar_filename)
      render :update do |page|                    # Use RJS to update the display
        page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        page.replace_html("main_div", :partial => "ui_4") # Replace the main div area contents
        if c_buttons && c_xml
          page << javascript_for_toolbar_reload('center_tb', c_buttons, c_xml)
          page << "$('#center_buttons_div').show();"
        else
          page << "$('#center_buttons_div').hide();"
        end
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
    render :action=>"show"
  end


  # AJAX driven routine to check for changes in ANY field on the form
  def form_field_changed
    # ui1 edit form
    return unless load_edit("config_edit__ui1","configuration")
    get_form_vars
    @assigned_filters = Array.new
    @changed = (@edit[:new] != @edit[:current])
    render :update do |page|                    # Use JS to update the display
      page.replace(@refresh_div, :partial=>@refresh_partial) if @refresh_div
      page << javascript_for_miq_button_visibility_changed(@changed)
    end
  end

  # AJAX driven routine to check for changes in ANY field on the user form
  def filters_field_changed
    # ui3 form
    return unless load_edit("config_edit__ui3","configuration")
    if params[:all_checked]                         # User checked/unchecked a tree node
      @edit[:show_ids] = params[:all_checked].split(',')
      if !@edit[:show_ids].blank?
        @edit[:new].each_with_index do |arr,i|
          if @edit[:show_ids].include?(arr.id.to_s)
            @edit[:new][i].search_key = nil
          else
            @edit[:new][i].search_key = "_hidden_"
          end
        end
      else      #if everything was unchecked
        @edit[:new].each_with_index do |search,i|
          @edit[:new][i].search_key = nil
        end
      end
    end
    @edit[:current].each_with_index do |arr,i|          #needed to compare each array element's attributes to find out if something has changed
      if @edit[:new][i].search_key != arr.search_key
        @changed = true
        break
      end
    end
    render :update do |page|
      # needed to compare each array element's attributes to find out if something has changed
      @edit[:current].each_with_index do |arr, i|
        id = @edit[:new][i].id
        if @edit[:new][i].search_key != @edit[:current][i].search_key
          style_class = 'cfme-blue-bold-node'
        else
          style_class = 'dynatree-title'
        end
        page << "cfme_dynatree_node_add_class('#{session[:tree_name]}', '#{id}', '#{style_class}')"
      end
      page << javascript_for_miq_button_visibility(@changed) if @changed
    end
  end

  # AJAX driven routine for gtl view selection
  def view_selected
    # ui2 form
    return unless load_edit("config_edit__ui2","configuration")
    @edit[:new][:views][VIEW_RESOURCES[params[:resource]]] = params[:view] # Capture the new view setting
    session[:changed] = (@edit[:new] != @edit[:current])
    @changed = session[:changed]
    render :update do |page|                    # Use JS to update the display
      page.replace 'tab_div', :partial=>"ui_2"
    end
  end

  # AJAX driven routine for theme selection
  def theme_changed
    # ui1 theme changed
    @edit = session[:edit]
    @edit[:new][:display][:theme] = params[:theme]      # Capture the new setting
    session[:changed] = (@edit[:new] != @edit[:current])
    @changed = session[:changed]
    render :update do |page|                    # Use JS to update the display
      page.replace 'tab_div', :partial=>"ui_1"
    end
  end

  # AJAX driven routine for nav style selection
  def nav_style_changed
    @edit = session[:edit]
    @edit[:new][:display][:nav_style] = params[:nav_style]    # Capture the new setting
    session[:changed] = (@edit[:new] != @edit[:current])
    @changed = session[:changed]
    render :update do |page|                    # Use JS to update the display
      page.replace 'tab_div', :partial=>"ui_1"
    end
  end

  # AJAX driven routine for background color selection
  def bg_color_changed
    # ui1 bgcolor changed
    @edit = session[:edit]
    @edit[:new][:display][:bg_color] = params[:bg_color]      # Capture the new setting
    session[:changed] = (@edit[:new] != @edit[:current])
    @changed = session[:changed]
    render :update do |page|                    # Use JS to update the display
      page.replace 'tab_div', :partial=>"ui_1"
    end
  end

  # Assign a tag to a set of objects
  def mytag_create
    if params[:newtags] && params[:newtags].present?     # If user entered tags
      newtags = params[:newtags]
      invalid_chars = newtags.gsub(/[\w\s]/, "")
      if invalid_chars.present?
        invalid_chars = invalid_chars.split(//).uniq.join # Get the unique invalid characters
        msg = "Invalid character".pluralize(invalid_chars.length)
        add_flash(msg + " #{invalid_chars} found in entered tags, only letters, numbers, and underscores are allowed.", :error)
        render :update do |page|
          page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        end
        return
      end
      newtags = params[:newtags].split                      # Put tags in array
      newtags.each do |t|
        Tag.add(t, :cat => session[:userid]) # Add each tag
      end
      session[:mytags] = Tag.all_tags(:cat => session[:userid]).sort      # Get all of the users tags
      render :update do |page|
        page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        page.replace("tab_div", :partial => "configuration/ui_5")
        newtags.each do |tag|
          page << jquery_pulsate_element("mytag#{tag}")
        end
      end
    end
  end

  # Remove a tag from a set of objects
  def mytag_delete
    Tag.remove(params[:tag], :cat => session[:userid])
    session[:mytags] = Tag.all_tags(:cat => session[:userid]).sort      # Get all of the users tags
    render :update do |page|
      page.replace("tab_div", :partial => "ui_5")
    end
  end

  def update
    if params["save"]
      get_form_vars if @tabform != "ui_3"
      case @tabform
      when "ui_1"                                                 # Visual tab
        @settings.merge!(@edit[:new])                                   # Apply the new saved settings

        # Remove any old settings hashes *****************************
        @settings[:display].delete(:pres_mode)                    # :pres_mode replaced by :theme

        db_user = User.find_by_userid(session[:userid])
        unless db_user.nil?                                       # Only if userid is in the DB
          db_user.settings = db_user.settings == nil ? @settings : db_user.settings.merge(@settings)  # Create or merge the settings into the db
          # Remove any old settings hashes *****************************
          db_user.settings[:display].delete(:pres_mode)           # :pres_mode replaced by :theme
          db_user.settings.delete(:css)                           # Moved this to @css
          db_user.settings.delete(:adv_search)                    # These got in around sprint 40 by accident
          db_user.save

          # Now copying ALL display settings into the :css hash so we can easily add new settings
          @settings[:css] ||= Hash.new
          @settings[:css].merge!(@settings[:display])
          @settings[:css].merge!(THEME_CSS_SETTINGS[@settings[:display][:theme]])

          @css ||= Hash.new
          @css.merge!(@settings[:display])
          @css.merge!(THEME_CSS_SETTINGS[@settings[:display][:theme]])
          set_user_time_zone
          add_flash(_("User Interface settings saved for User %s") %  session[:username])
        else
          add_flash(_("User Interface settings saved for this session"))
        end
        edit
        render :action => "show"
        return                                                    # No config file for Visuals yet, just return
      when "ui_2"                                                 # Visual tab
        @settings.merge!(@edit[:new])                                   # Apply the new saved settings

        # Remove any old settings hashes *****************************
        @settings[:display].delete(:pres_mode)                    # :pres_mode replaced by :theme
        @settings[:display].delete(:vmcompare)                    # :vmcompare moved to :views hash
        @settings[:display].delete(:vm_summary_cool)              # :vm_summary_cool moved to :views hash
        @settings[:views].delete(:vm_summary_cool)                # :views/:vm_summary_cool changed to :dashboards
        @settings[:views].delete(:dashboards)                    # :dashboards is obsolete now

        db_user = User.find_by_userid(session[:userid])
        unless db_user.nil?                                       # Only if userid is in the DB
          db_user.settings = db_user.settings == nil ? @settings : db_user.settings.merge(@settings)  # Create or merge the settings into the db
          # Remove any old settings hashes *****************************
          db_user.settings[:display].delete(:pres_mode)           # :pres_mode replaced by :theme
          db_user.settings[:display].delete(:vmcompare)           # :vmcompare moved to :views hash
          db_user.settings[:display].delete(:vm_summary_cool)     # :vm_summary_cool moved to :views hash
          db_user.settings[:views].delete(:vm_summary_cool)       # :views/:vm_summary_cool changed to :dashboards
          db_user.save
          add_flash(_("User Interface settings saved for User %s") %  session[:username])
        else
          add_flash(_("User Interface settings saved for this session"))
        end
        edit
        render :action => "show"
        return                                                      # No config file for Visuals yet, just return
      when "ui_3"                                                   # User Filters tab
        @edit = session[:edit]
        @edit[:current].each do |arr|
          s = MiqSearch.find(arr.id.to_i)
          if @edit[:show_ids]
            if @edit[:show_ids].include?(s.id.to_s)
              s.search_key = nil
            else
              s.search_key = "_hidden_"
            end
            s.save
          end
        end
        add_flash(_("Default Filters saved successfully"))
        edit
        render :action => "show"
        return                                                      # No config file for Visuals yet, just return
      when "ui_4"                                                   # User Filters tab
        @edit = session[:edit]
        @edit[:current].each do |arr|
          s = MiqSearch.find(arr.id.to_i)
          if @edit[:show_ids]
            if @edit[:show_ids].include?(s.id.to_s)
              s.search_key = nil
            else
              s.search_key = "_hidden_"
            end
            s.save
          end
        end
        add_flash(_("Default Filters saved successfully"))
        edit
        render :action => "show"
        return                                                      # No config file for Visuals yet, just return
      when "ui_5"                                                   # My tags, mytag_create method
      end
      @update.config.each_key do |category|
        @update.config[category] = @edit[:new][category].dup
      end
      if @update.validate                                           # Have VMDB class validate the settings
        @update.save                                              # Save other settings for current server
        AuditEvent.success(build_config_audit(@edit[:new], @edit[:current].config))
        add_flash(_("Configuration settings saved"))
        edit
        render :action => "show"
      else
        @update.errors.each do |field,msg|
          add_flash("#{field.titleize}: #{msg}", :error)
        end
        @changed = true
        session[:changed] = @changed
        build_tabs
        render :action => "show"
      end
    elsif params["reset"]
      edit
      add_flash(_("All changes have been reset"), :warning)
      render :action => "show"
    end
  end

  # Show the users list
  def show_timeprofiles
    build_tabs if params[:action] == "change_tab" || ["cancel","add","save"].include?(params[:button])
    if session[:userrole] == "super_administrator" || session[:userrole] == "administrator"
      @temp[:timeprofiles] = TimeProfile.in_my_region.all(:order => "lower(description) ASC")
    else
      @temp[:timeprofiles] = TimeProfile.in_my_region.all(:conditions=> ["(profile_type = ? or (profile_type = ? and  profile_key = ?))", "global", "user", session[:userid]], :order => "lower(description) ASC")
    end
    timeprofile_set_days_hours
    drop_breadcrumb( {:name=>"Time Profiles", :url=>"/configuration/change_tab/?tab=4"})
  end

  def timeprofile_set_days_hours(timeprofile=@timeprofile)
    @temp[:timeprofile_details] = Hash.new
    @temp[:timeprofiles].each do |timeprofile|
      @temp[:timeprofile_details][timeprofile.description] = Hash.new
      @temp[:timeprofile_details][timeprofile.description][:days] = Array.new
      timeprofile.profile[:days].each do |day|
        @temp[:timeprofile_details][timeprofile.description][:days].push(
          DateTime::ABBR_DAYNAMES[day.to_i])
      end
      @temp[:timeprofile_details][timeprofile.description][:hours] = Array.new
      temp_arr = Array.new
      timeprofile.profile[:hours].each do |h|
        temp_arr.push(h.to_i)
      end
      temp_arr = temp_arr.sort
      st = ""
      temp_arr.each_with_index do |hr,i|
        if hr.to_i+1 == temp_arr[i+1]
          st = "#{get_hr_str(hr).split('-').first}-" if st == ""
        else
          if st != ""
            @temp[:timeprofile_details][timeprofile.description][:hours].push(st + get_hr_str(hr).split('-').last)
          else
            @temp[:timeprofile_details][timeprofile.description][:hours].push(get_hr_str(hr))
          end
          st = ""
        end
      end
      if @temp[:timeprofile_details][timeprofile.description][:hours].length > 1 && @temp[:timeprofile_details][timeprofile.description][:hours].first.split('-').first == "12AM" && @temp[:timeprofile_details][timeprofile.description][:hours].last.split('-').last == "12AM"      #manipulating midnight hours to be displayed on show screen
        @temp[:timeprofile_details][timeprofile.description][:hours][0] = @temp[:timeprofile_details][timeprofile.description][:hours].last.split('-').first + '-' + @temp[:timeprofile_details][timeprofile.description][:hours].first.split('-').last
        @temp[:timeprofile_details][timeprofile.description][:hours].delete_at(@temp[:timeprofile_details][timeprofile.description][:hours].length-1)
      end
      @temp[:timeprofile_details][timeprofile.description][:tz] = timeprofile.profile[:tz]
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
    @breadcrumbs = Array.new
    drop_breadcrumb( {:name=>"Add new Time Profile", :url=>"/configuration/timeprofile_edit"} )
    render :action=>"timeprofile_edit"
  end

  def timeprofile_edit
    assert_privileges("tp_edit")
    @timeprofile = TimeProfile.find(params[:id])
    set_form_vars
    @tp_restricted = true if @timeprofile.profile_type == "global" && session[:userrole] != "super_administrator" &&  session[:userrole] != "administrator"
    title = (@timeprofile.profile_type == "global" && session[:userrole] != "super_administrator" &&  session[:userrole] != "administrator") ? "Time Profile" : "Edit"
    add_flash(_("Global Time Profile cannot be edited")) if @timeprofile.profile_type == "global" && session[:userrole] != "super_administrator" &&  session[:userrole] != "administrator"
    session[:changed] = false
    @in_a_form = true
    drop_breadcrumb( {:name=>"#{title} '#{@timeprofile.description}'", :url=>"/configuration/timeprofile_edit"} )
  end

  # Delete all selected or single displayed VM(s)
  def timeprofile_delete
    assert_privileges("tp_delete")
    timeprofiles = Array.new
    if !params[:id] # showing a list, scan all selected timeprofiles
      timeprofiles = find_checked_items
      if timeprofiles.empty?
        add_flash(_("No %s were selected for deletion") % ui_lookup(:models=>"TimeProfile"), :error)
      else
        selected_timeprofiles = TimeProfile.find_all_by_id(timeprofiles)
        selected_timeprofiles.each do |tp|
          if tp.description == "UTC"
            timeprofiles.delete(tp.id.to_s)
            add_flash(_("Default %{model} \"%{name}\" cannot be deleted") % {:model => ui_lookup(:model => "TimeProfile"), :name  => tp.description},
                      :error)
          elsif tp.profile_type == "global" &&
              session[:userrole] != "super_administrator" &&
              session[:userrole] != "administrator"
            timeprofiles.delete(tp.id.to_s)
            add_flash(_("\"%{name}\": Global %{model} cannot be deleted") % {:name  => tp.description, :model => ui_lookup(:models => "TimeProfile")},
                      :error)
          elsif !tp.miq_reports.empty?
            timeprofiles.delete(tp.id.to_s)
            add_flash(_("\"%{name}\": In use by %{rep_count}, cannot be deleted") % {:name      => tp.description, :rep_count => pluralize(tp.miq_reports.count, "report")},
                      :error)
          end
        end
      end
      process_timeprofiles(timeprofiles, "destroy") unless timeprofiles.empty?
    end
    set_form_vars
  end

  def timeprofile_get_form_vars
    @edit = session[:edit]
    @timeprofile = @edit[:timeprofile]
    @edit[:new][:description] = params[:description] if params[:description]
    @edit[:new][:profile_type] = params[:profile_type] if params[:profile_type]
    @edit[:new][:profile][:tz] = params[:profile_tz].blank? ? nil : params[:profile_tz] if params.key?(:profile_tz)
    @redraw = true if params.key?(:profile_tz)
    @edit[:new][:rollup_daily] = params[:rollup_daily] == "1" || nil if params.key?(:rollup_daily)
    @edit[:new][:profile_key] = @edit[:new][:profile_type] == "user" ? session[:userid] : nil
    params.each do |var, val|
      vars=var.split("_")
      if vars[0]=="days"
        val=="1" ?
          @edit[:new][:profile][:days].push(vars[1].to_i) :
          @edit[:new][:profile][:days].delete(vars[1].to_i)
          @edit[:new][:profile][:days] = @edit[:new][:profile][:days].uniq.sort
        break
      elsif vars[0]=="hours"
        val=="1" ?
          @edit[:new][:profile][:hours].push(vars[1].to_i) :
          @edit[:new][:profile][:hours].delete(vars[1].to_i)
          @edit[:new][:profile][:hours] = @edit[:new][:profile][:hours].uniq.sort
        break
      end
    end
    if params[:all_days]
      @edit[:all_days] = params[:all_days] == "1"
      @edit[:new][:profile][:days] = params[:all_days] == "1" ? Array.new(7) {|i| i} : []
      @redraw = true
    end
    if params[:all_hours]
      @edit[:all_hours] = params[:all_hours] == "1"
      @edit[:new][:profile][:hours] = params[:all_hours] == "1" ? Array.new(24) {|i| i} : []
      @redraw = true
    end
  end

  def timeprofile_field_changed
    return unless load_edit("config_edit__ui4","configuration")
    timeprofile_get_form_vars
    changed = (@edit[:new] != @edit[:current])
    render :update do |page|                    # Use JS to update the display
      page.replace('timeprofile_days_hours_div',
                   :partial => "timeprofile_days_hours",
                   :locals  => {:disabled => false}) if @redraw
      if params.key?(:profile_tz) && ["super_administrator", "administrator"].include?(session[:userrole])
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
    @timeprofile.description = "Copy of " + timeprofile.description
    @timeprofile.profile_type = "user"
    @timeprofile.profile_key = timeprofile.profile_key
    if !timeprofile.profile.nil?
      @timeprofile.profile ||= Hash.new
      @timeprofile.profile[:days] = timeprofile.profile[:days] if timeprofile.profile[:days]
      @timeprofile.profile[:hours] = timeprofile.profile[:hours] if timeprofile.profile[:hours]
      @timeprofile.profile[:tz] = timeprofile.profile[:tz] if timeprofile.profile[:tz]
    end
    set_form_vars
    session[:changed] = false
    drop_breadcrumb( {:name=>"Adding copy of '#{@timeprofile.description}'", :url=>"/configuration/timeprofile_edit"} )
    render :action=>"timeprofile_edit"
  end

  def show
    show_timeprofiles if params[:typ] == "timeprofiles"
  end

  def timeprofile_create
    assert_privileges("timeprofile_new")
    timeprofile_get_form_vars
    case params[:button]
    when "cancel"
      add_flash(_("Add of new %s was cancelled by the user") % ui_lookup(:model=>"TimeProfile"))
      session[:flash_msgs] = @flash_array.dup                 # Put msgs in session for next transaction
      render :update do |page|
        page.redirect_to :action=>'change_tab', :typ=>"timeprofiles", :tab=>4
      end
    when "add"
      if @edit[:new][:description].nil? || @edit[:new][:description] == ""
        add_flash(_("%s is required") % "Description", :error)
      end
      if @edit[:new][:profile][:days].length <= 0
        add_flash(_("At least one %s must be selected") % "Day", :error)
      end
      if @edit[:new][:profile][:hours].length <= 0
        add_flash(_("At least one %s must be selected") % "Hour", :error)
      end
      if @flash_array != nil
        drop_breadcrumb( {:name=>"Add New Time Profile", :url=>"/configuration/timeprofile_edit"} )
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
        return
      end
      timeprofile_set_record_vars(@timeprofile)
      begin
        @timeprofile.save!
      rescue StandardError => bang
        add_flash(_("Error during '%s': ") % "add" << bang.message, :error)
        @in_a_form = true
        drop_breadcrumb( {:name=>"Add New Time Profile", :url=>"/configuration/timeprofile_edit"} )
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
      else
        AuditEvent.success(build_created_audit(@timeprofile, @edit))
        add_flash(_("%{model} \"%{name}\" was added") % {:model=>ui_lookup(:model=>"TimeProfile"), :name=>@timeprofile.description})
        session[:flash_msgs] = @flash_array.dup                 # Put msgs in session for next transaction
        render :update do |page|
          page.redirect_to :action=>'change_tab', :typ=>"timeprofiles", :tab=>4
        end
      end
    end
  end

  def timeprofile_update
    assert_privileges("tp_edit")
    timeprofile_get_form_vars
    if params[:button] == "cancel"
      add_flash(_("Edit of %{model} \"%{name}\" was cancelled by the user") % {:model=>ui_lookup(:model=>"TimeProfile"), :name=>@timeprofile.description})
      params[:id] = @timeprofile.id.to_s
      session[:flash_msgs] = @flash_array.dup                 # Put msgs in session for next transaction
      render :update do |page|
        page.redirect_to :action=>'change_tab', :typ=>"timeprofiles", :tab=>4, :id =>@timeprofile.id.to_s
      end
    elsif params[:button] == "reset"
      @edit[:new] = copy_hash(@edit[:current])
      params[:id] = @timeprofile.id
      add_flash(_("All changes have been reset"), :warning)
      @changed = session[:changed] = (@edit[:new] != @edit[:current])
      drop_breadcrumb( {:name=>"Edit '#{@timeprofile.description}'", :url=>"/configuration/timeprofile_edit"} )
      session[:flash_msgs] = @flash_array.dup                 # Put msgs in session for next transaction
      render :update do |page|
        page.redirect_to :action=>'timeprofile_edit', :id =>@timeprofile.id.to_s
      end
    elsif params[:button] == "save"
      if @edit[:new][:description].nil? || @edit[:new][:description] == ""
        add_flash(_("%s is required") % "Description", :error)
      end
      if @edit[:new][:profile][:days].length <= 0
        add_flash(_("At least one %s must be selected") % "Day", :error)
      end
      if @edit[:new][:profile][:hours].length <= 0
        add_flash(_("At least one %s must be selected") % "Hour", :error)
      end
      unless @flash_array.nil?
        @changed = session[:changed] = (@edit[:new] != @edit[:current])
        drop_breadcrumb( {:name=>"Edit '#{@timeprofile.description}'", :url=>"/configuration/timeprofile_edit"} )
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
        return
      end
      timeprofile = TimeProfile.find(@edit[:timeprofile].id)    # get the current record
      timeprofile_set_record_vars(timeprofile)
      begin
        timeprofile.save!
      rescue StandardError => bang
        add_flash(_("%{model} \"%{name}\": Error during '%{task}': ") % {:model=>"TimeProfile", :name=>timeprofile.description, :task=>"save"} << bang.message,
                  :error)
        @in_a_form = true
        drop_breadcrumb( {:name=>"Edit '#{timeprofile.description}'", :url=>"/configuration/timeprofile_edit"} )
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
      else
        AuditEvent.success(build_created_audit(timeprofile, @edit))
        add_flash(_("%{model} \"%{name}\" was saved") % {:model=>ui_lookup(:model=>"TimeProfile"), :name=>timeprofile.description})
        session[:flash_msgs] = @flash_array.dup                 # Put msgs in session for next transaction
        render :update do |page|
          page.redirect_to :action=>'change_tab', :typ=>"timeprofiles", :tab=>4, :id =>@timeprofile.id.to_s
        end
      end
    end
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

  def timeprofile_set_record_vars(profile)
    profile.description = @edit[:new][:description]
    profile.profile_type = @edit[:new][:profile_type]
    profile.profile_key = @edit[:new][:profile_key]
    @edit[:new][:profile].delete(:tz) if @edit[:new][:profile][:tz].nil? || @edit[:new][:profile][:tz] == ""  # No need to pass timezone if it is set to use default
    profile.profile = @edit[:new][:profile]
    profile.rollup_daily_metrics = @edit[:new][:profile][:tz] == nil ? false : @edit[:new][:rollup_daily]
  end

  def build_tabs
    @breadcrumbs = Array.new
    case @config_tab
    when "ui"
      @tabs = Array.new
      drop_breadcrumb( {:name=>"User Interface Configuration", :url=>"/configuration/edit" }, true ) if @tabform != "ui_4"
      case @tabform
      when "ui_1"
        @tabs[0] = ["1", ""]  # Start with first tab array entry set to tab 1 as active
      when "ui_2"
        @tabs[0] = ["2", ""]  # Start with first tab array entry set to tab 1 as active
      when "ui_3"
        @tabs[0] = ["3", ""]  # Start with first tab array entry set to tab 1 as active
      when "ui_4"
        @tabs[0] = ["4", ""]  # Start with first tab array entry set to tab 1 as active
      when "ui_5"
        @tabs[0] = ["5", ""]  # Start with first tab array entry set to tab 1 as active
      end
      @tabs.push( ["1", "Visual"] ) if role_allows(:feature=>"my_settings_visuals")
      @tabs.push( ["2", "Default Views"] ) if role_allows(:feature=>"my_settings_default_views")
      @tabs.push( ["3", "Default Filters"] ) if role_allows(:feature=>"my_settings_default_filters")
      @tabs.push( ["4", "Time Profiles"] ) if role_allows(:feature=>"my_settings_time_profiles")
      @tabs.push( ["5", "MyTags"] ) if role_allows(:feature=>"my_settings_my_tags") if false
    end
  end

  NAV_TAB_PATH =  {
                    :host => ["Infrastructure", "Hosts"],
                    :miqtemplate => ["Services", "Workloads", "Templates & Images"],
                    :storage => ["Infrastructure", "Datastores"],
                    :templatecloud => ["Cloud", "Instances", "Images"],
                    :templateinfra => ["Infrastructure", "Virtual Machines", "Templates"],
                    :vm => ["Services", "Workloads", "VMs & Instances"],
                    :vmcloud => ["Cloud", "Instances", "Instances"],
                    :vminfra => ["Infrastructure", "Virtual Machines", "VMs"]
                  }

  def merge_in_user_settings(settings)
    db_user = User.find_by_userid(session[:userid])
    if db_user.try(:settings)
      settings.each do |key, value|
        value.merge!(db_user.settings[key]) unless db_user.settings[key].nil?
      end
    end
    settings
  end
  hide_action :merge_in_user_settings

  # * start with DEFAULT_SETTINGS
  # * merge in current session changes
  # * merge in any settings from the DB if they exist
  def init_settings
    merge_in_user_settings(copy_hash(DEFAULT_SETTINGS))
  end
  hide_action :init_settings

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
        pages.push([page[1], page[0]]) if role_allows(:feature => page[2], :any => true)
      end
    when 'ui_2'
      @edit = {
        :current => init_settings,
        :key     => 'config_edit__ui2',
      }
    when 'ui_3'
      current = MiqSearch.all(:conditions=>["search_type=?", "default"]).sort_by do |a|
        [NAV_TAB_PATH[a.db.downcase.to_sym], a.description.downcase]
      end
      @edit = {
        :key         => 'config_edit__ui3',
        :set_filters => true,
        :current     => current,
      }
      build_default_filters_tree(@edit[:current])
    when 'ui_4'
      @edit = {
        :timeprofile => @timeprofile,
        :current     => {},
        :key         => 'config_edit__ui4',
      }
      if ['timeprofile_new',  'timeprofile_copy',
          'timeprofile_edit', 'timeprofile_update'].include?(params[:action])
        @edit[:current] = {
          :description  => @timeprofile.description,
          :profile_type => @timeprofile.profile_type || "user",
          :profile_key  => @timeprofile.profile_key,
          :profile => {
            :days  => Array(@timeprofile.days).uniq.sort,
            :hours => Array(@timeprofile.hours).uniq.sort,
            :tz    => @timeprofile.tz,
          },
          :rollup_daily => @timeprofile.rollup_daily_metrics,
        }
        @edit[:all_days]  = @edit.fetch_path(:current, :profile, :days).length  == 7
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
      @edit[:new][:quadicons][:ems] = params[:quadicons_ems] == "1" if params[:quadicons_ems]
      @edit[:new][:quadicons][:ems_cloud] = params[:quadicons_ems_cloud] == "1" if params[:quadicons_ems_cloud]
      @edit[:new][:quadicons][:host] = params[:quadicons_host] == "1" if params[:quadicons_host]
      @edit[:new][:quadicons][:vm] = params[:quadicons_vm] == "1" if params[:quadicons_vm]
      @edit[:new][:quadicons][:miq_template] = params[:quadicons_miq_template] == "1" if params[:quadicons_miq_template]
      if get_vmdb_config[:product][:proto] # Hide behind proto setting - Sprint 34
        @edit[:new][:quadicons][:service] = params[:quadicons_service] == "1" if params[:quadicons_service]
      end
      @edit[:new][:quadicons][:storage] = params[:quadicons_storage] == "1" if params[:quadicons_storage]
      @edit[:new][:perpage][:grid] = params[:perpage_grid].to_i if params[:perpage_grid]
      @edit[:new][:perpage][:tile] = params[:perpage_tile].to_i if params[:perpage_tile]
      @edit[:new][:perpage][:list] = params[:perpage_list].to_i if params[:perpage_list]
      @edit[:new][:perpage][:reports] = params[:perpage_reports].to_i if params[:perpage_reports]
      @edit[:new][:display][:theme] = params[:display_theme] if params[:display_theme] != nil
      @edit[:new][:display][:bg_color] = params[:bg_color] if params[:bg_color] != nil
      @edit[:new][:display][:reporttheme] = params[:display_reporttheme] if params[:display_reporttheme] != nil
      @edit[:new][:display][:dashboards] = params[:display_dashboards] if params[:display_dashboards] != nil
      @edit[:new][:display][:timezone] = params[:display_timezone] if params[:display_timezone] != nil
      @edit[:new][:display][:startpage] = params[:start_page] if params[:start_page] != nil
      @edit[:new][:display][:quad_truncate] = params[:quad_truncate] if params[:quad_truncate] != nil
      @edit[:new][:display][:locale] = params[:display_locale] if params[:display_locale]
    when "ui_2"                                               # Visual Settings tab
      @edit[:new][:display][:compare] = params[:display][:compare] if params[:display] != nil && params[:display][:compare] != nil
      @edit[:new][:display][:drift] = params[:display][:drift] if params[:display] != nil && params[:display][:drift] != nil
    when "ui_3"                                               # Visual Settings tab
      @edit[:new][:display][:compare] = params[:display][:compare] if params[:display] != nil && params[:display][:compare] != nil
      @edit[:new][:display][:drift] = params[:display][:drift] if params[:display] != nil && params[:display][:drift] != nil
    when "ui_4"                                               # Visual Settings tab
      @edit[:new][:display][:compare] = params[:display][:compare] if params[:display] != nil && params[:display][:compare] != nil
      @edit[:new][:display][:drift] = params[:display][:drift] if params[:display] != nil && params[:display][:drift] != nil
    end
  end

  # Build the default filters tree for the search views
  def build_default_filters_tree(all_def_searches)
    all_views = []                                   # Array to hold all CIs
    all_def_searches.collect do |search|  # Go thru all of the Searches
      folder_nodes = NAV_TAB_PATH[search[:db].downcase.to_sym]
      add_main_tab_node(folder_nodes, search.id) if @main_tab.nil? || @main_tab != folder_nodes[0]
      add_sub_tab_node(folder_nodes, search.id)  if @sub_tab.blank? || @sub_tab != folder_nodes[1]
      add_ci_tab_node(folder_nodes, search.id)   if folder_nodes.length == 3 &&
          (@ci_tab.blank? || @ci_tab != folder_nodes[2])
      # check if this is last folder node, add filters
      if folder_nodes.length == 2 && (!@sub_tab.blank? || @sub_tab == folder_nodes[1])
        node = build_filter_node(search)
        @sub_tab_children.push(node) unless @sub_tab_children.include?(node)
      elsif folder_nodes.length == 3 && (!@ci_tab.blank? || @ci_tab == folder_nodes[2])
        node = build_filter_node(search)
        @search_filter_nodes.push(node) unless @search_filter_nodes.include?(node)
      end
      @ci_tab_node[:children]   = @search_filter_nodes unless @search_filter_nodes.blank?
      @sub_tab_node[:children]  = @sub_tab_children    unless @sub_tab_children.blank?
      @main_tab_node[:children] = @main_tab_children   unless @main_tab_children.blank?
      all_views.push(@main_tab_node).uniq!
    end
    @temp[:all_views_tree] = all_views.to_json
    session[:tree_name]    = "all_views_tree"
  end

  def add_main_tab_node(folder_nodes, search_id)
    @main_tab          = folder_nodes.first
    @main_tab_node     = build_folder_node(@main_tab, search_id, true)
    @main_tab_children = []
  end

  def add_sub_tab_node(folder_nodes, search_id)
    @sub_tab      = folder_nodes[1]
    @sub_tab_node = build_folder_node(@sub_tab, search_id, folder_nodes.length > 2)
    @main_tab_children.push(@sub_tab_node)
    @sub_tab_children = []
  end

  def add_ci_tab_node(folder_nodes, search_id)
    @ci_tab      = folder_nodes[2]
    @ci_tab_node = build_folder_node(@ci_tab, search_id)
    @sub_tab_children.push(@ci_tab_node)
    @search_filter_nodes = []
  end

  def build_folder_node(title, id, expanded = false)
    TreeNodeBuilder.generic_tree_node(
      "#{title}_#{id}",
      title,
      "folder.png",
      title,
      :style_class  => "cfme-no-cursor-node",
      :hideCheckbox => true,
      :expand       => expanded
    )
  end

  def build_filter_node(rec)
    TreeNodeBuilder.generic_tree_node(
      rec[:id].to_s,
      rec[:description],
      "filter.png",
      rec[:description],
      :style_class => "cfme-no-cursor-node",
      :select      => rec[:search_key] != "_hidden_"
    )
  end

  def get_tree_image(db)
    db.constantize.base_model.name.underscore
  end

  def get_session_data
    @title        = session[:config_title] ? "Configuration" : session[:config_title]
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
end
