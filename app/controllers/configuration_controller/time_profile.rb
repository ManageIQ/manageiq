module ConfigurationController::TimeProfile
  extend ActiveSupport::Concern

  # route
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

  def timeprofile_get_form_vars
    @edit = session[:edit]
    @timeprofile = ::TimeProfile.find(@edit[:timeprofile_id]) if @edit[:timeprofile_id]
    @edit[:new][:description] = params[:description] if params[:description]
    @edit[:new][:profile_type] = params[:profile_type] if params[:profile_type]
    @edit[:new][:profile][:tz] = params[:profile_tz].blank? ? nil : params[:profile_tz] if params.key?(:profile_tz)
    @redraw = true if params.key?(:profile_tz)
    @edit[:new][:rollup_daily] = params[:rollup_daily] == "1" || nil if params.key?(:rollup_daily)
    @edit[:new][:profile_key] = @edit[:new][:profile_type] == "user" ? session[:userid] : nil
    params.each do |var, val|
      vars = var.split("_")
      if vars[0] == "days"
        val == "1" ?
          @edit[:new][:profile][:days].push(vars[1].to_i) :
          @edit[:new][:profile][:days].delete(vars[1].to_i)
        @edit[:new][:profile][:days] = @edit[:new][:profile][:days].uniq.sort
        break
      elsif vars[0] == "hours"
        val == "1" ?
          @edit[:new][:profile][:hours].push(vars[1].to_i) :
          @edit[:new][:profile][:hours].delete(vars[1].to_i)
        @edit[:new][:profile][:hours] = @edit[:new][:profile][:hours].uniq.sort
        break
      end
    end
    if params[:all_days]
      @edit[:all_days] = params[:all_days] == "1"
      @edit[:new][:profile][:days] = params[:all_days] == "1" ? Array.new(7) { |i| i } : []
      @redraw = true
    end
    if params[:all_hours]
      @edit[:all_hours] = params[:all_hours] == "1"
      @edit[:new][:profile][:hours] = params[:all_hours] == "1" ? Array.new(24) { |i| i } : []
      @redraw = true
    end
  end

  def timeprofile_create
    assert_privileges("timeprofile_new")
    timeprofile_get_form_vars
    case params[:button]
    when "cancel"
      add_flash(_("Add of new %{record} was cancelled by the user") % {:record => ui_lookup(:model => "TimeProfile")})
      session[:flash_msgs] = @flash_array.dup                 # Put msgs in session for next transaction
      render :update do |page|
        page << javascript_prologue
        page.redirect_to :action => 'change_tab', :typ => "timeprofiles", :tab => 4
      end
    when "add"
      if @edit[:new][:description].nil? || @edit[:new][:description] == ""
        add_flash(_("Description is required"), :error)
      end
      if @edit[:new][:profile][:days].length <= 0
        add_flash(_("At least one Day must be selected"), :error)
      end
      if @edit[:new][:profile][:hours].length <= 0
        add_flash(_("At least one Hour must be selected"), :error)
      end
      unless @flash_array.nil?
        drop_breadcrumb(:name => _("Add New Time Profile"), :url => "/configuration/timeprofile_edit")
        render :update do |page|
          page << javascript_prologue
          page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        end
        return
      end
      @timeprofile = ::TimeProfile.new unless @timeprofile
      timeprofile_set_record_vars(@timeprofile)
      begin
        @timeprofile.save!
      rescue StandardError => bang
        add_flash(_("Error during 'add': %{error_message}") % {:error_message => bang.message}, :error)
        @in_a_form = true
        drop_breadcrumb(:name => _("Add New Time Profile"), :url => "/configuration/timeprofile_edit")
        render :update do |page|
          page << javascript_prologue
          page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        end
      else
        AuditEvent.success(build_created_audit(@timeprofile, @edit))
        add_flash(_("%{model} \"%{name}\" was added") % {:model => ui_lookup(:model => "TimeProfile"), :name => @timeprofile.description})
        session[:flash_msgs] = @flash_array.dup                 # Put msgs in session for next transaction
        render :update do |page|
          page << javascript_prologue
          page.redirect_to :action => 'change_tab', :typ => "timeprofiles", :tab => 4
        end
      end
    end
  end

  def timeprofile_update
    assert_privileges("tp_edit")
    timeprofile_get_form_vars
    if params[:button] == "cancel"
      add_flash(_("Edit of %{model} \"%{name}\" was cancelled by the user") % {:model => ui_lookup(:model => "TimeProfile"), :name => @timeprofile.description})
      params[:id] = @timeprofile.id.to_s
      session[:flash_msgs] = @flash_array.dup                 # Put msgs in session for next transaction
      render :update do |page|
        page << javascript_prologue
        page.redirect_to :action => 'change_tab', :typ => "timeprofiles", :tab => 4, :id => @timeprofile.id.to_s
      end
    elsif params[:button] == "reset"
      @edit[:new] = copy_hash(@edit[:current])
      params[:id] = @timeprofile.id
      add_flash(_("All changes have been reset"), :warning)
      @changed = session[:changed] = (@edit[:new] != @edit[:current])
      drop_breadcrumb(:name => _("Edit '%{description}'") % {:description => @timeprofile.description},
                      :url  => "/configuration/timeprofile_edit")
      session[:flash_msgs] = @flash_array.dup                 # Put msgs in session for next transaction
      render :update do |page|
        page << javascript_prologue
        page.redirect_to :action => 'timeprofile_edit', :id => @timeprofile.id.to_s
      end
    elsif params[:button] == "save"
      if @edit[:new][:description].nil? || @edit[:new][:description] == ""
        add_flash(_("Description is required"), :error)
      end
      if @edit[:new][:profile][:days].length <= 0
        add_flash(_("At least one Day must be selected"), :error)
      end
      if @edit[:new][:profile][:hours].length <= 0
        add_flash(_("At least one Hour must be selected"), :error)
      end
      unless @flash_array.nil?
        @changed = session[:changed] = (@edit[:new] != @edit[:current])
        drop_breadcrumb(:name => _("Edit '%{description}'") % {:description => @timeprofile.description},
                        :url  => "/configuration/timeprofile_edit")
        render :update do |page|
          page << javascript_prologue
          page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        end
        return
      end
      timeprofile_set_record_vars(@timeprofile)
      begin
        @timeprofile.save!
      rescue StandardError => bang
        add_flash(_("TimeProfile \"%{name}\": Error during 'save': %{error_message}") %
          {:name => @timeprofile.description, :error_message => bang.message}, :error)
        @in_a_form = true
        drop_breadcrumb(:name => _("Edit '%{description}'") % {:description => @timeprofile.description},
                        :url  => "/configuration/timeprofile_edit")
        render :update do |page|
          page << javascript_prologue
          page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        end
      else
        AuditEvent.success(build_created_audit(@timeprofile, @edit))
        add_flash(_("%{model} \"%{name}\" was saved") % {:model => ui_lookup(:model => "TimeProfile"),
                                                         :name  => @timeprofile.description})
        session[:flash_msgs] = @flash_array.dup                 # Put msgs in session for next transaction
        render :update do |page|
          page << javascript_prologue
          page.redirect_to :action => 'change_tab', :typ => "timeprofiles", :tab => 4, :id => @timeprofile.id.to_s
        end
      end
    end
  end

  def timeprofile_copy
    assert_privileges("tp_copy")
    session[:set_copy] = "copy"
    @in_a_form = true
    timeprofile = ::TimeProfile.find(params[:id])
    @timeprofile = ::TimeProfile.new
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

  def timeprofile_set_record_vars(profile)
    profile.description = @edit[:new][:description]
    profile.profile_type = @edit[:new][:profile_type]
    profile.profile_key = @edit[:new][:profile_key]
    @edit[:new][:profile].delete(:tz) if @edit[:new][:profile][:tz].nil? || @edit[:new][:profile][:tz] == ""  # No need to pass timezone if it is set to use default
    profile.profile = @edit[:new][:profile]
    profile.rollup_daily_metrics = @edit[:new][:profile][:tz].nil? ? false : @edit[:new][:rollup_daily]
  end

  def timeprofile_set_form_vars
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

  def timeprofile_new
    assert_privileges("timeprofile_new")
    @timeprofile = ::TimeProfile.new
    set_form_vars
    @in_a_form = true
    @breadcrumbs = []
    drop_breadcrumb(:name => _("Add new Time Profile"), :url => "/configuration/timeprofile_edit")
    render :action => "timeprofile_edit"
  end

  def timeprofile_edit
    assert_privileges("tp_edit")
    @timeprofile = ::TimeProfile.find(params[:id])
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

  # Show the users list
  def show_timeprofiles
    build_tabs if params[:action] == "change_tab" || ["cancel", "add", "save"].include?(params[:button])
    if admin_user?
      @timeprofiles = ::TimeProfile.in_my_region.ordered_by_desc
    else
      @timeprofiles = ::TimeProfile.in_my_region.for_user(session[:userid]).ordered_by_desc
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
        selected_timeprofiles = ::TimeProfile.where(:id => timeprofiles)
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
            add_flash(_("\"%{name}\": In use by %{rep_count}, cannot be deleted") % {:name      => tp.description, :rep_count => pluralize(tp.miq_reports.count, "report")},
                      :error)
          end
        end
      end
      process_timeprofiles(timeprofiles, "destroy") unless timeprofiles.empty?
    end
    set_form_vars
  end

  def show
    show_timeprofiles if params[:typ] == "timeprofiles"
  end

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

  def timeprofile_button
    timeprofile_delete if params[:pressed] == "tp_delete"
    copy_record if params[:pressed] == "tp_copy"
    edit_record if params[:pressed] == "tp_edit"
  end
end
