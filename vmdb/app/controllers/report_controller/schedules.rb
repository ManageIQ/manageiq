module ReportController::Schedules
  extend ActiveSupport::Concern

  def show_schedule
    if @schedule.nil?
      redirect_to :action=>"schedules", :flash_msg=>_("Error: Record no longer exists in the database"), :flash_error=>true
      return
    end

    # Get configured tz, else use user's tz
    @timezone = (@schedule.run_at && @schedule.run_at[:tz]) ? @schedule.run_at[:tz] : session[:user_tz]

    if @schedule.filter.is_a?(MiqExpression)
       record      = MiqReport.find_by_id(@schedule.filter.exp["="]["value"])
       @rep_filter = record.name
    end
    @breadcrumbs = Array.new
    drop_breadcrumb( {:name=>@schedule.name, :url=>"/report/show_schedule/#{@schedule.id}"} )
    if @schedule.sched_action[:options] && @schedule.sched_action[:options][:email]
      @temp[:email_to] = Array.new
      @schedule.sched_action[:options][:email][:to].each_with_index do |e, e_idx|
        u = User.find_by_email(e)
        @temp[:email_to].push(u ? "#{u.name} (#{e})" : e)
      end
    end
    #render :action=>"show_schedule"
  end

  def schedule_get_all
    @temp[:schedules]    = true
    @force_no_grid_xml   = true
    @gtl_type            = "list"
    @ajax_paging_buttons = true
    if params[:ppsetting]                                             # User selected new per page value
      @items_per_page = params[:ppsetting].to_i                       # Set the new per page value
      @settings[:perpage][@gtl_type.to_sym] = @items_per_page         # Set the per page setting for this gtl type
    end
    @sortcol = session[:schedule_sortcol].nil? ? 0 : session[:schedule_sortcol].to_i
    @sortdir = session[:schedule_sortdir].nil? ? "ASC" : session[:schedule_sortdir]

    if session[:userrole] == "super_administrator"  # Super admins see all user's schedules
      @view, @pages = get_view(MiqSchedule, :conditions=>["towhat=?", "MiqReport"]) # Get the records (into a view) and the paginator
    else
      @view, @pages = get_view(MiqSchedule, :conditions=>["towhat=? AND userid=?", "MiqReport", session[:userid]])  # Get the records (into a view) and the paginator
    end

    @current_page = @pages[:current] unless @pages.nil? # save the current page number
    session[:schedule_sortcol] = @sortcol
    session[:schedule_sortdir] = @sortdir

    @sb[:tree_typ]   = "schedules"
    @right_cell_text = I18n.t("cell_header.all_model_records",
                              :model=>ui_lookup(:models=>"MiqSchedule"))
    @right_cell_div  = "schedule_list"
  end

  def schedule_new
    assert_privileges("miq_report_schedule_add")
    @schedule        = MiqSchedule.new(:userid=>session[:userid])
    @in_a_form       = true
    @schedule.towhat = "MiqReport"
    if @sb[:tree_typ] == "reports"
      exp                   = Hash.new
      exp["="]              = {"field"=>"MiqReport.id", "value"=>@sb[:miq_report_id]}
      @_params.delete :id   #incase add schedule button was pressed from report show screen.
      @schedule.filter      = MiqExpression.new(exp)
      miq_report            = MiqReport.find(@sb[:miq_report_id])
      @schedule.name        = miq_report.name
      @schedule.description = miq_report.title
      @changed = session[:changed] = true
    end
    schedule_edit
  end
  alias_method :miq_report_schedule_add, :schedule_new

  # Delete all selected or single displayed action(s)
  def miq_report_schedule_delete
    assert_privileges("miq_report_schedule_delete")
    scheds = find_checked_items
    if params[:id]
      if MiqSchedule.exists?(from_cid(params[:id]))
        scheds.push(from_cid(params[:id]))
      else
        add_flash(I18n.t("flash.record.no_longer_exists", :model => ui_lookup(:model => "MiqSchedule")), :error)
      end
    end
    process_schedules(scheds, "destroy")  unless scheds.empty?
    unless flash_errors?
      msg_str = scheds.length > 1 ? "selected_records_deleted" : "selected_record_deleted"
      add_flash(I18n.t("flash.#{msg_str}",
                       :model => "#{ui_lookup(:model => "MiqReport")} #{ui_lookup(:models => "MiqSchedule")}"),
                :info, true)
    end
    self.x_node = "root"
    replace_right_cell(:replace_trees => [:schedules])
  end

  def miq_report_schedule_run_now
    assert_privileges("miq_report_schedule_run_now")
    scheds = find_checked_items
    if scheds.empty? && params[:id].nil?
      add_flash(_("No Report Schedules were selected to be Run now"), :error)
      render :update do |page|
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
      end
    else
      if MiqSchedule.exists?(from_cid(params[:id]))
        scheds.push(from_cid(params[:id]))
      else
        add_flash(I18n.t("flash.record.no_longer_exists", :model => ui_lookup(:model => "MiqSchedule")), :error)
      end
    end
    MiqSchedule.find_all_by_id(scheds, :order => "lower(name)").each do |sched|
      MiqSchedule.queue_scheduled_work(sched.id, nil, Time.now.utc.to_i, nil)
      audit = {:event=>"queue_scheduled_work", :message=>"Schedule [#{sched.name}] queued to run from the UI by user #{session[:username]}", :target_id=>sched.id, :target_class=>"MiqSchedule", :userid => session[:userid]}
      AuditEvent.success(audit)
    end
    unless flash_errors?
      add_flash(I18n.t("flash.schedule#{params[:id] ? "" : "s"}_queued_to_run"), :info, true)
    end
    get_node_info
    replace_right_cell
  end

  def schedule_toggle(enable)
    assert_privileges("miq_report_schedule_#{enable ? 'enable' : 'disable'}")
    present_action = enable ? 'enable' : 'disable'
    past_action = present_action + 'd'

    scheds = find_checked_items
    if scheds.empty?
        add_flash(I18n.t("flash.no_records_selected_to_be_#{past_action}",
                            :model=>"#{ui_lookup(:model=>"MiqReport")} #{ui_lookup(:models=>"MiqSchedule")}"),
                            :error)
        render :update do |page|
            page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
    end
    schedule_enable_disable(scheds, present_action) unless scheds.empty?
    add_flash(I18n.t("flash.selected_records_were_#{past_action}",
                            :model=>"#{ui_lookup(:model=>"MiqReport")} #{ui_lookup(:models=>"MiqSchedule")}"),
                            :info, true) unless flash_errors?
    schedule_get_all
    replace_right_cell
  end

  def miq_report_schedule_enable
    schedule_toggle(true)
  end

  def miq_report_schedule_disable
    schedule_toggle(false)
  end

    # AJAX driven routine to check for changes in ANY field on the form
  def schedule_form_field_changed
    return unless load_edit("schedule_edit__#{params[:id]}","replace_cell__explorer")
    schedule_get_form_vars
    if @edit[:new][:filter]
      @folders ||= Array.new
      schedule_menus
    end
    render :update do |page|                    # Use JS to update the display
      if params[:filter_typ]
        @edit[:new][:subfilter] = nil
        @edit[:new][:repfilter] = @reps = nil
        page.replace("form_filter_div", :partial=>"schedule_form_filter")
      elsif params[:subfilter_typ]
        @edit[:new][:repfilter] = nil
        page.replace("form_filter_div", :partial=>"schedule_form_filter")
      end

      javascript_for_timer_type(params[:timer_typ]).each { |js| page << js }

      if params[:time_zone]
        page << "miq_cal_dateFrom = new Date(#{(Time.now - 1.month).in_time_zone(@edit[:tz]).strftime("%Y,%m,%d")});"
        page << "miqBuildCalendar();"
        page << "$('miq_date_1').value = '#{@edit[:new][:start_date]}';"
        page << "$('start_hour').value = '#{@edit[:new][:start_hour].to_i}';"
        page << "$('start_min').value = '#{@edit[:new][:start_min].to_i}';"
        page.replace_html("tz_span", @timezone_abbr)
      end
      if @email_refresh
        page.replace("edit_email_div",
                      :partial=>"layouts/edit_email",
                      :locals=>{:action_url=>"schedule_form_field_changed",
                                :box_title=>"E-Mail after Running",
                                :record=>@schedule})
        page.replace("schedule_email_options_div", :partial=>"schedule_email_options")
      end
      changed = (@edit[:new] != @edit[:current])
      if changed != session[:changed]
        session[:changed] = changed
        page << javascript_for_miq_button_visibility(changed)
      end
      page << "miqSparkle(false);"
    end
  end

  def schedule_edit
    assert_privileges("miq_report_schedule_edit")
    case params[:button]
      when "cancel"
        @schedule = MiqSchedule.find_by_id(session[:edit][:sched_id]) if session[:edit] && session[:edit][:sched_id]
        if !@schedule || @schedule.id.blank?
          add_flash(I18n.t("flash.add.cancelled", :model=>ui_lookup(:model=>"MiqSchedule")))
        else
          add_flash(I18n.t("flash.edit.cancelled", :model=>ui_lookup(:model=>"MiqSchedule"), :name=>@schedule.name))
        end
        @schedule = nil
        @edit = session[:edit] = nil  # clean out the saved info
        self.x_active_tree = :schedules_tree
        self.x_node = "root"
        @in_a_form = false
        @sb[:active_accord] = :schedules
        replace_right_cell
      when "save", "add"
        id = params[:id] ? params[:id] : "new"
        return unless load_edit("schedule_edit__#{id}","replace_cell__explorer")
        schedule = @edit[:sched_id] ? MiqSchedule.find(@edit[:sched_id]) :  MiqSchedule.new(:userid=>session[:userid])
        if !@edit[:new][:repfilter] || @edit[:new][:repfilter] == ""
          add_flash(I18n.t("flash.edit.select_required", :selection=>"A Report"), :error)
        end
        schedule_set_record_vars(schedule)
        schedule_valid?(schedule)
        if schedule.valid? && !flash_errors? && schedule.save
          AuditEvent.success(build_saved_audit(schedule, @edit))
          @edit[:sched_id] ?
            add_flash(I18n.t("flash.edit.saved",
                          :model=>ui_lookup(:model=>"MiqSchedule"),
                          :name=>schedule.name)) :
            add_flash(I18n.t("flash.add.added",
                          :model=>ui_lookup(:model=>"MiqSchedule"),
                          :name=>schedule.name))
          params[:id] = schedule.id.to_s    # reset id in params for show
          @edit = session[:edit] = nil # clean out the saved info

          # ensure we land in the right accordion with the right tree and
          # with the listing opened even when entering 'add' from the reports
          # menu
          @sb[:active_tree]   = :schedules_tree
          @sb[:active_accord] = :schedules
          # fixme: change to x_active_node after 5.2
          @sb[:trees][@sb[:active_tree]][:active_node] = 'root'

          replace_right_cell(:replace_trees => [:schedules])
        else
          schedule.errors.each do |field,msg|
            add_flash("#{field.to_s.capitalize} #{msg}", :error)
          end
          @changed = session[:changed] = (@edit[:new] != @edit[:current])
          drop_breadcrumb( {:name=>"Edit Schedule", :url=>"/miq_schedule/edit"} )
          render :update do |page|
            page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
          end
        end
      when "reset", nil # Reset or first time in
        add_flash(_("All changes have been reset"), :warning) if params[:button] == "reset"
        if x_active_tree != :reports_tree
          #dont set these if new schedule is being added from a report show screen
          obj = find_checked_items
          obj[0] = params[:id] if obj.blank? && params[:id]
          @schedule = obj[0] && params[:id] != "new" ? MiqSchedule.find(obj[0]) :
              MiqSchedule.new(:userid=>session[:userid])  # Get existing or new record
          session[:changed] = false
        end
        schedule_set_form_vars
        schedule_build_edit_screen
        @lock_tree = true
        replace_right_cell
    end
  end
  alias_method :miq_report_schedule_edit, :schedule_edit

  private

    # Common Schedule button handler routines
  def process_schedules(schedules, task)
    process_elements(schedules, MiqSchedule, task)
  end

  def schedule_menus
    @folders = Array.new
    @menu.each do |r|
      @folders.push(r[0])
      if @edit[:new][:filter] && @edit[:new][:filter] != ""
        @sub_folders ||= Array.new
        if r[0] == @edit[:new][:filter]
          r[1].each do |subfolder,reps|
            subfolder.to_miq_a.each do |s|
              @sub_folders.push(s)
            end
            if @edit[:new][:subfilter] && @edit[:new][:subfilter] != ""
              @reps ||= Array.new
              if subfolder == @edit[:new][:subfilter]
                reps.each do |r|
                  temp_arr = Array.new
                  rec = MiqReport.find_by_name(r.strip)
                  if rec
                    temp_arr.push(r)
                    temp_arr.push(rec.id)
                    @reps.push(temp_arr) if !@reps.include?(temp_arr)
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  # Validate some of the schedule fields
  def schedule_valid?(sched)
    valid = true
    if sched.sched_action[:options] &&
        sched.sched_action[:options][:send_email] &&
        sched.sched_action[:options][:email] &&
        sched.sched_action[:options][:email][:to].blank?
      valid = false
      add_flash(I18n.t("flash.edit.at_least_1.configured",
                      :field=>"To E-mail address"),
                :error)
    end
    unless flash_errors?
      if sched.run_at[:interval][:unit] == "once" &&
        sched.run_at[:start_time].to_time.utc < Time.now.utc &&
        sched.enabled == true
        add_flash(_("Warning: This 'Run Once' timer is in the past and will never run as currently configured"), :warning)
      end
    end
    return valid
  end

  # Set form variables for edit
  def schedule_set_form_vars
    @timezone_abbr = get_timezone_abbr("server")
    @edit = Hash.new
    @folders = Array.new

    # Remember how this edit started
    @edit[:type] = %w(miq_report_schedule_copy
                      miq_report_schedule_new).include?(params[:action]) ? "schedule_new" : "schedule_edit"

    # Get configured tz, default to user's tz
    @edit[:tz] = @schedule.run_at && @schedule.run_at[:tz] ? @schedule.run_at[:tz] : session[:user_tz]

    @edit[:sched_id] = @schedule.id
    @edit[:new]      = Hash.new
    @edit[:current]  = Hash.new
    @edit[:key]      = "schedule_edit__#{@schedule.id || "new"}"
    @menu            = get_reports_menu
    @menu.each { |r| @folders.push(r[0]) }

    @edit[:new][:name]        = @schedule.name
    @edit[:new][:description] = @schedule.description
    @edit[:new][:enabled]     = @schedule.enabled.nil? ? false : @schedule.enabled
    @edit[:new][:send_email]  = @schedule.sched_action.nil? || !@schedule.sched_action.has_key?(:options) ?
                                false :
                                @schedule.sched_action[:options][:send_email] == true
    @edit[:new][:email]       = Hash.new
    if @schedule.sched_action && @schedule.sched_action[:options] && @schedule.sched_action[:options][:email]
      @edit[:new][:email] = copy_hash(@schedule.sched_action[:options][:email])
    end
    @edit[:new][:email][:send_if_empty] = true if @edit[:new][:email][:send_if_empty].nil?

    if @schedule.sched_action && @schedule.sched_action[:options] && @schedule.sched_action[:options][:email]
      # rebuild hash to hold user's email along with name if user record was found for display, defined as hash so only email id can be sent from form to be deleted from array above
      @temp[:email_to] = Hash.new
      @schedule.sched_action[:options][:email][:to].each_with_index do |e, e_idx|
        u = User.find_by_email(e)
        @temp[:email_to][e] = u ? "#{u.name} (#{e})" : e
      end
    end

    if @schedule.filter
      record = MiqReport.find_by_id(@schedule.filter.exp["="]["value"])
      @menu.each do |m|
        m[1].each do |f|
            f.each do |r|
              if r.class != String
                r.each do |rep|
                  if rep == record.name
                    @edit[:new][:filter] = m[0]
                    @edit[:new][:subfilter] = f[0]
                  end
              end
            end
          end
        end
      end
      @edit[:new][:repfilter] = record.id
      schedule_menus
    end
    set_edit_timer_from_schedule(@schedule)

    @edit[:current] = copy_hash(@edit[:new])
    session[:edit] = @edit
  end

  # Get variables from edit form
  def schedule_get_form_vars
    @schedule = @edit[:sched_id] ? MiqSchedule.find_by_id(@edit[:sched_id]) :
        MiqSchedule.new(:userid=>session[:userid])
    @edit[:new][:name] = params[:name] if params[:name]
    @edit[:new][:description] = params[:description] if params[:description]
    @edit[:new][:enabled] = (params[:enabled] == "1") if params[:enabled]
    @edit[:new][:filter] = params[:filter_typ] if params[:filter_typ]
    @edit[:new][:subfilter] = params[:subfilter_typ] if params[:subfilter_typ]
    if params[:repfilter_typ] && params[:repfilter_typ] != "<Choose>"
      rep = MiqReport.find(params[:repfilter_typ].to_i)
      @edit[:new][:repfilter] = rep.id
    elsif params[:repfilter_typ] && params[:repfilter_typ] == "<Choose>"
      @edit[:new][:repfilter] = nil
    end
    @edit[:new][:timer_typ] = params[:timer_typ] if params[:timer_typ]
    @edit[:new][:timer_months] = params[:timer_months] if params[:timer_months]
    @edit[:new][:timer_weeks] = params[:timer_weeks] if params[:timer_weeks]
    @edit[:new][:timer_days] = params[:timer_days] if params[:timer_days]
    @edit[:new][:timer_hours] = params[:timer_hours] if params[:timer_hours]
    @edit[:new][:start_date] = params[:miq_date_1] if params[:miq_date_1]
    @edit[:new][:start_hour] = params[:start_hour] if params[:start_hour]
    @edit[:new][:start_min] = params[:start_min] if params[:start_min]

    if params[:time_zone]
      @edit[:tz] = params[:time_zone]
      @timezone_abbr = Time.now.in_time_zone(@edit[:tz]).strftime("%Z")
      t = Time.now.in_time_zone(@edit[:tz]) + 1.day # Default date/time to tomorrow in selected time zone
      @edit[:new][:start_date] = "#{t.month}/#{t.day}/#{t.year}"  # Reset the start date
      @edit[:new][:start_hour] = "00" # Reset time to midnight
      @edit[:new][:start_min] = "00"
    end

    @edit[:new][:filter] = "" if @edit[:new][:filter] == "<Choose>"
    @edit[:new][:subfilter] = "" if @edit[:new][:subfilter] == "<Choose>"

    @edit[:new][:email][:from] = params[:from] if params.has_key?(:from)
    @edit[:email] = params[:email] if params.has_key?(:email)
    if params[:user_email]
      @edit[:new][:email][:to] ||= Array.new
      @edit[:new][:email][:to].push(params[:user_email])
      @edit[:new][:email][:to].sort!
      @edit[:user_emails].delete(params[:user_email])
    end

    if params[:button] == "add_email"
      @edit[:new][:email][:to] ||= Array.new
      @edit[:new][:email][:to].push(@edit[:email]) unless @edit[:email].blank? || @edit[:new][:email][:to].include?(@edit[:email])
      @edit[:new][:email][:to].sort!
      @edit[:email] = nil
    end

    if params[:remove_email]
      @edit[:new][:email][:to].delete(params[:remove_email])
      build_user_emails_for_edit
    end

    if params[:user_email] || params[:button] == "add_email" || params[:remove_email]
      # rebuild hash to hold user's email along with name if user record was found for display, defined as hash so only email id can be sent from form to be deleted from array above
      @temp[:email_to] = Hash.new
      @edit[:new][:email][:to].each_with_index do |e, e_idx|
        u = User.find_by_email(e)
        @temp[:email_to][e] = u ? "#{u.name} (#{e})" : e
      end
    end

    @edit[:new][:email][:send_if_empty] = (params[:send_if_empty] == "1") if params.has_key?(:send_if_empty)

    if params.has_key?(:send_txt) || params.has_key?(:send_csv) || params.has_key?(:send_pdf)
      @edit[:new][:email][:attach] ||= Array.new
      if params.has_key?(:send_txt)
        params[:send_txt] == "1" ? @edit[:new][:email][:attach].push(:txt) : @edit[:new][:email][:attach].delete(:txt)
      end
      if params.has_key?(:send_csv)
        params[:send_csv] == "1" ? @edit[:new][:email][:attach].push(:csv) : @edit[:new][:email][:attach].delete(:csv)
      end
      if params.has_key?(:send_pdf)
        params[:send_pdf] == "1" ? @edit[:new][:email][:attach].push(:pdf) : @edit[:new][:email][:attach].delete(:pdf)
      end
      @edit[:new][:email].delete(:attach) if @edit[:new][:email][:attach].blank?
    end

    @edit[:new][:send_email] = (params[:send_email_cb] == "1") if params.has_key?(:send_email_cb)
    @email_refresh = true if params[:user_email] || params[:remove_email] ||
                              params[:button] == "add_email" || params.has_key?(:send_email_cb)

  end

  def schedule_build_edit_screen
    @schedule = @edit[:sched_id] ? MiqSchedule.find_by_id(@edit[:sched_id]) :
        MiqSchedule.new(:userid=>session[:userid])
    @in_a_form = true
    build_user_emails_for_edit
  end

  # Set record variables to new values
  def schedule_set_record_vars(schedule)
    schedule.name = @edit[:new][:name]
    schedule.description = @edit[:new][:description]
    schedule.enabled = @edit[:new][:enabled]
    schedule.towhat = "MiqReport"                           # Default schedules apply to MiqReport model for now
    schedule.sched_action = { :method=>"run_report",                    # Set method
                              :options=>{ :send_email=>@edit[:new][:send_email] == true,  # Set send_email flag
                                          :email_url_prefix=>url_for(:controller=>"report", :action=>"show_saved") + "/"  # Set email URL
                                        }
                            }
    schedule.sched_action[:options][:email] = copy_hash(@edit[:new][:email]) if @edit[:new][:send_email]

    schedule.run_at ||= Hash.new
    run_at = create_time_in_utc("#{@edit[:new][:start_date]} #{@edit[:new][:start_hour]}:#{@edit[:new][:start_min]}:00",
                                @edit[:tz])
    schedule.run_at[:start_time] = "#{run_at} Z"
    schedule.run_at[:tz] = @edit[:tz]
    schedule.run_at[:interval] ||= Hash.new
    schedule.run_at[:interval][:unit] = @edit[:new][:timer_typ].downcase
    case @edit[:new][:timer_typ].downcase
    when "monthly"
      schedule.run_at[:interval][:value] = @edit[:new][:timer_months]
    when "weekly"
      schedule.run_at[:interval][:value] = @edit[:new][:timer_weeks]
    when "daily"
      schedule.run_at[:interval][:value] = @edit[:new][:timer_days]
    when "hourly"
      schedule.run_at[:interval][:value] = @edit[:new][:timer_hours]
    else
      schedule.run_at[:interval].delete(:value)
    end

    # Build the filter expression
    exp = Hash.new

    unless !@edit[:new][:repfilter] || @edit[:new][:repfilter] == ""
      record = MiqReport.find(@edit[:new][:repfilter].to_i)
      exp["="] = {"field"=>"MiqReport.id", "value"=>record.id} if record
      schedule.filter = MiqExpression.new(exp)
    end
  end

  def build_schedules_tree(type = :schedules, name = :schedules_tree)
    x_tree_init(name, type, "MiqSchedule", :open_all => true)
    tree_nodes = x_build_dynatree(x_tree(name))

    # Fill in root node details
    root           = tree_nodes.first
    root[:title]   = "All Schedules"
    root[:tooltip] = "All Schedules"
    root[:icon]    = "miq_schedule.png"
    @temp[name]    = tree_nodes.to_json          # JSON object for tree loading
    x_node_set(tree_nodes.first[:key], name) unless x_node(name)  # Set active node to root if not set
  end

  def get_schedule(nodeid)
    @record = @schedule = MiqSchedule.find(from_cid(nodeid.split('__').last).to_i)
    show_schedule
    @right_cell_text = I18n.t("cell_header.model_record",
                              :name=>@schedule.name,
                              :model=>ui_lookup(:model=>"MiqSchedule"))
    @right_cell_div  = "schedule_list"
  end

end
