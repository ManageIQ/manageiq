module MiqPolicyController::Alerts
  extend ActiveSupport::Concern

  def alert_edit
    assert_privileges(params[:pressed]) if params[:pressed]
    case params[:button]
    when "cancel"
      @edit = nil
      @alert = session[:edit][:alert_id] ? MiqAlert.find_by_id(session[:edit][:alert_id]) : MiqAlert.new
      if @alert && @alert.id.blank?
        add_flash(_("Add of new %s was cancelled by the user") % ui_lookup(:model=>"MiqAlert"))
      else
        add_flash(_("Edit of %{model} \"%{name}\" was cancelled by the user") % {:model=>ui_lookup(:model=>"MiqAlert"), :name=>@alert.description})
      end
      get_node_info(x_node)
      replace_right_cell(@nodetype)
    when "save", "add"
      id = params[:id] && params[:button] != "add" ? params[:id] : "new"
      return unless load_edit("alert_edit__#{id}","replace_cell__explorer")
      @alert = @edit[:alert_id] ? MiqAlert.find_by_id(@edit[:alert_id]) : MiqAlert.new
      alert = @alert.id.blank? ? MiqAlert.new : MiqAlert.find(@alert.id)  # Get new or existing record
      alert_set_record_vars(alert)
      if alert_valid_record?(alert) && alert.valid? && !@flash_array && alert.save
        AuditEvent.success(build_saved_audit(alert, params[:button] == "add"))
        flash_key = params[:button] == "save" ? _("%{model} \"%{name}\" was saved") : _("%{model} \"%{name}\" was added")
        add_flash(flash_key % {:model => ui_lookup(:model => "MiqAlert"), :name => @edit[:new][:description]})
        alert_get_info(MiqAlert.find(alert.id))
        @edit = nil
        @nodetype = "al"
        @new_alert_node = "al-#{to_cid(alert.id)}"
        replace_right_cell("al", [:alert_profile, :alert])
      else
        alert.errors.each do |field,msg|
          add_flash("#{field.to_s.capitalize} #{msg}", :error)
        end
        replace_right_cell("al")
      end
    when "reset", nil # Reset or first time in
      alert_build_edit_screen
      @sb[:action] = "alert_edit"
      if params[:button] == "reset"
        add_flash(_("All changes have been reset"), :warning)
      end
      replace_right_cell("al")
    end
  end

  def alert_delete
    assert_privileges("alert_delete")
    alerts = Array.new
    # showing 1 alert, delete it
    if params[:id] == nil || MiqAlert.find_by_id(params[:id]).nil?
      add_flash(_("%s no longer exists") % ui_lookup(:model=>"MiqAlert"),
                  :error)
    else
      alerts.push(params[:id])
    end
    process_alerts(alerts, "destroy") unless alerts.empty?
    add_flash(_("The selected %s was deleted") % ui_lookup(:models=>"MiqAlert")) if @flash_array == nil
    @new_alert_node = self.x_node = "root"
    get_node_info(x_node)
    replace_right_cell("root", [:alert_profile, :alert])
  end

  def alert_field_changed
    return unless load_edit("alert_edit__#{params[:id]}","replace_cell__explorer")
    @alert = @edit[:alert_id] ? MiqAlert.find_by_id(@edit[:alert_id]) : MiqAlert.new

    @edit[:new][:description] = params[:description].blank? ? nil : params[:description] if params[:description]
    @edit[:new][:enabled] = params[:enabled_cb] == "1" if params.has_key?(:enabled_cb)
    if params[:exp_event]
      @edit[:new][:exp_event] = params[:exp_event] == "_hourly_timer_" ? params[:exp_event] : params[:exp_event].to_i
      @edit[:new][:repeat_time] = alert_default_repeat_time
    end
    @edit[:new][:repeat_time] = params[:repeat_time].to_i if params[:repeat_time]
    @edit[:new][:event_name] = params[:event_name] if params[:event_name]

# Removed following line, not allowing this option to be changed in the UI at this time (v3.3, sprint 66)
#   @edit[:new][:expression][:mode] = params[:use_automate_cb] == "1" ? "automate" : "internal" if params.has_key?(:use_automate_cb)

    if params[:miq_alert_db]
      @edit[:new][:db] = params[:miq_alert_db]
      @edit[:expression_types] = MiqAlert.expression_types(@edit[:new][:db])
      if @edit[:expression_types].blank?
        alert_build_blank_exp
      else
        @edit[:new][:expression] = {:eval_method=>@edit[:expression_types].invert.sort.to_a.first.last,
                                    :mode=>"internal"}
        @edit[:new][:expression][:options] = Hash.new
        @edit[:expression_options] = MiqAlert.expression_options(@edit[:new][:expression][:eval_method])
        alert_build_exp_options_info
      end
    end

    if params.has_key?(:exp_name)
      if params[:exp_name].blank?                                       # Set to MiqExpression
        alert_build_blank_exp
      else
        @edit[:new][:expression] = {:eval_method=>params[:exp_name], :mode=>"internal"}
        @edit[:new][:expression][:options] = Hash.new
        @edit[:expression_options] = MiqAlert.expression_options(@edit[:new][:expression][:eval_method])
        alert_build_exp_options_info
      end
      @edit[:new][:repeat_time] = alert_default_repeat_time
    end

    @edit[:new][:expression][:options][:event_types] = [params[:event_types]] if params[:event_types]
    @edit[:new][:expression][:options][:time_threshold] = params[:time_threshold].to_i if params[:time_threshold]
    @edit[:new][:expression][:options][:hourly_time_threshold] = params[:hourly_time_threshold].to_i if params[:hourly_time_threshold]
    @edit[:new][:expression][:options][:freq_threshold] = params[:freq_threshold] if params[:freq_threshold]
    if params[:perf_column]
      @edit[:new][:expression][:options][:perf_column] = params[:perf_column]
      @edit[:perf_column_unit] = alert_get_perf_column_unit(@edit[:perf_column_options][@edit[:new][:expression][:options][:perf_column]])
    end
    @edit[:new][:expression][:options][:operator] = params[:select_operator] if params[:select_operator]
    @edit[:new][:expression][:options][:value_threshold] = params[:value_threshold] if params[:value_threshold]
    if params[:trend_direction]
      @edit[:new][:expression][:options][:trend_direction] = params[:trend_direction]
      @edit[:new][:expression][:options].delete(:trend_steepness) unless params[:trend_direction].ends_with?("more_than")
      @edit[:perf_column_unit] = alert_get_perf_column_unit(@edit[:perf_column_options][@edit[:new][:expression][:options][:perf_column]])
    end
    @edit[:new][:expression][:options][:trend_steepness] = params[:trend_steepness] if params[:trend_steepness]
    @edit[:new][:expression][:options][:rt_time_threshold] = params[:rt_time_threshold].to_i if params[:rt_time_threshold]
    @edit[:new][:expression][:options][:event_log_message_filter_type] = params[:select_event_log_message_filter_type] if params[:select_event_log_message_filter_type]
    @edit[:new][:expression][:options][:event_log_message_filter_value] = params[:event_log_message_filter_value] if params[:event_log_message_filter_value]
    @edit[:new][:expression][:options][:event_log_name] = params[:event_log_name] if params[:event_log_name]
    @edit[:new][:expression][:options][:event_log_level] = params[:event_log_level] if params[:event_log_level]
    @edit[:new][:expression][:options][:event_log_event_id] = params[:event_log_event_id] if params[:event_log_event_id]
    @edit[:new][:expression][:options][:event_log_source] = params[:event_log_source] if params[:event_log_source]
    @edit[:new][:expression][:options][:hdw_attr] = params[:select_hdw_attr] if params[:select_hdw_attr]
    @edit[:new][:expression][:options][:debug_trace] = params[:debug_trace] if params[:debug_trace]

    # Handle VMware Alarm parms
    if params.has_key?(:select_ems_id)
      if params[:select_ems_id].blank?
        @edit[:new][:expression][:options][:ems_id] = nil
        @edit[:new][:expression][:options][:ems_alarm_mor] = nil
        @edit[:new][:expression][:options][:ems_alarm_name] = nil
      else
        @edit[:new][:expression][:options][:ems_id] = params[:select_ems_id].to_i
        @edit[:ems_alarms] = alert_build_ems_alarms
      end
    end
    if params.has_key?(:select_ems_alarm_mor)
      if params[:select_ems_alarm_mor].blank?
        @edit[:new][:expression][:options][:ems_alarm_mor] = nil
        @edit[:new][:expression][:options][:ems_alarm_name] = nil
      else
        @edit[:new][:expression][:options][:ems_alarm_mor] = params[:select_ems_alarm_mor]
        @edit[:new][:expression][:options][:ems_alarm_name] = @edit[:ems_alarms][params[:select_ems_alarm_mor]]
      end
    end

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

    @alert_snmp_refresh = build_snmp_options(:snmp, @edit[:new][:send_snmp])

    @edit[:new][:send_email]     = (params[:send_email_cb]     == "1") if params.has_key?(:send_email_cb)
    @edit[:new][:send_snmp]      = (params[:send_snmp_cb]      == "1") if params.has_key?(:send_snmp_cb)
    @edit[:new][:send_evm_event] = (params[:send_evm_event_cb] == "1") if params.has_key?(:send_evm_event_cb)
    @edit[:new][:send_event]     = (params[:send_event_cb]     == "1") if params.has_key?(:send_event_cb)

    @alert_refresh = true if params[:miq_alert_db] || params.has_key?(:exp_name) || params[:exp_event] ||
                            params.has_key?(:send_snmp_cb) || params.has_key?(:send_email_cb) ||
                            params.has_key?(:send_event_cb) || params.has_key?(:select_ems_id) ||
                            params.has_key?(:perf_column) || params.has_key?(:trend_direction)
    @to_email_refresh = true if params[:user_email] || params[:remove_email] || params[:button] == "add_email"
    send_button_changes
  end

  def alert_get_all
    peca_get_all('alert', lambda { get_view(MiqAlert) } )
  end

  private

  def process_alerts(alerts, task)
    process_elements(alerts, MiqAlert, task)
  end

  def alert_build_edit_screen
    @edit = Hash.new
    @edit[:new] = Hash.new
    @edit[:current] = Hash.new

    if params[:copy]  # If copying, create a new alert based on the original
      a = MiqAlert.find(params[:id])
      @alert = MiqAlert.new(a.attributes)
    else
      @alert = params[:id] ? MiqAlert.find(params[:id]) : MiqAlert.new  # Get existing or new record
      @alert.enabled = true unless @alert.id            # Default enabled to true if new record
    end
    @edit[:key] = "alert_edit__#{@alert.id || "new"}"
    @edit[:rec_id] = @alert.id || nil

    @edit[:alert_id] = @alert.id
    @edit[:new][:email] = Hash.new
    @edit[:new][:snmp] = Hash.new
    if @alert.options && @alert.options[:notifications] && @alert.options[:notifications][:email]
      @edit[:new][:email] = copy_hash(@alert.options[:notifications][:email])
      @edit[:new][:send_email] = true
      # build hash to hold user's email along with name if user record was found for display, defined as hash so only email id can be sent from form to be deleted from array above
      @temp[:email_to] = Hash.new
      if @edit[:new][:email] && @edit[:new][:email][:to]
        @edit[:new][:email][:to].each_with_index do |e, e_idx|
          u = User.find_by_email(e)
          @temp[:email_to][e] = u ? "#{u.name} (#{e})" : e
        end
      end
    end
    if @alert.options && @alert.options[:notifications] && @alert.options[:notifications][:snmp]
      @edit[:new][:snmp] = copy_hash(@alert.options[:notifications][:snmp])
      @edit[:new][:snmp][:host] = @alert.options[:notifications][:snmp][:host] ? @alert.options[:notifications][:snmp][:host].to_a : Array.new(3)
      @edit[:new][:send_snmp] = true
    end
    @edit[:new][:snmp][:host] ||= Array.new(3)
    if @alert.options && @alert.options[:notifications] && @alert.options[:notifications][:evm_event]
      @edit[:new][:send_evm_event] = true
    end
    if @alert.options && @alert.options[:notifications] && @alert.options[:notifications][:automate]
      @edit[:new][:event_name] = @alert.options[:notifications][:automate][:event_name]
      @edit[:new][:send_event] = true
    end
    @edit[:new][:send_snmp] ||= false
    @edit[:new][:send_evm_event] ||= false
    @edit[:new][:send_event] ||= false
    alert_build_snmp_variables
    build_user_emails_for_edit

    # Build hash of arrays of all events by event type
    @edit[:events] = Hash.new
    MiqEvent.all_events.each do |e|
      next if e.name.ends_with?("compliance_check")
      @edit[:events][e.id] = (e.etype.description + ": " + e.description)
    end

    # Build hash of all mgmt systems by id
    @edit[:emss] = Hash.new
    ExtManagementSystem.all.each do |e|
      @edit[:emss][e.id] = e.name
    end

    @edit[:new][:description] = @alert.description
    @edit[:new][:enabled] = @alert.enabled == true
    @edit[:new][:db] = @alert.db == nil ? "Vm" : @alert.db
    @edit[:expression_types] = MiqAlert.expression_types(@edit[:new][:db])

    if @alert.expression.is_a?(MiqExpression)
      build_expression(@alert, @edit[:new][:db])
    elsif @alert.expression == nil
      @edit[:new][:expression] = {:eval_method=>@edit[:expression_types].invert.sort.to_a.first.last, :mode=>"internal"}
      @edit[:new][:expression][:options] = Hash.new
      @edit[:expression_options] = MiqAlert.expression_options(@edit[:new][:expression][:eval_method])
      alert_build_exp_options_info
    else
      @edit[:new][:expression] = copy_hash(@alert.expression)             # Copy the builtin exp hash
      @edit[:expression_options] = MiqAlert.expression_options(@edit[:new][:expression][:eval_method])
      alert_build_exp_options_info
    end

    if @alert.expression.is_a?(MiqExpression)                             # If an exp alert, get the event id
      if @alert.responds_to_events == "_hourly_timer_"                    # Check for hourly timer event
        @edit[:new][:exp_event] = @alert.responds_to_events
      else
        exp_event = MiqEvent.find_by_name(@alert.responds_to_events)
        @edit[:new][:exp_event] = exp_event.nil? ? nil : exp_event.id
      end
    elsif @alert.expression.is_a?(Hash) && @alert.expression[:eval_method] == "nothing"
      if @alert.responds_to_events == "_hourly_timer_"                    # Check for hourly timer event
        @edit[:new][:exp_event] = @alert.responds_to_events
      else
        exp_event = MiqEvent.find_by_name(@alert.responds_to_events)
        @edit[:new][:exp_event] = exp_event.nil? ? nil : exp_event.id
      end
    end

    # Build hash of alarms if mgmt system option is present is present
    if !@alert.expression.is_a?(MiqExpression) &&
        @edit[:new][:expression][:options] && @edit[:new][:expression][:options][:ems_id]
      @edit[:ems_alarms] = alert_build_ems_alarms
    end

    # Set the repeat time based on the existing options
    @edit[:new][:repeat_time] ||= @alert.options &&                     # Default repeat time to 10 mins
                                  @alert.options[:notifications] &&
                                  !@alert.options[:notifications][:delay_next_evaluation].blank? ?
                                  @alert.options[:notifications][:delay_next_evaluation] :
                                  alert_default_repeat_time

    @edit[:current] = copy_hash(@edit[:new])

    @edit[:dbs] = Hash.new
    MiqAlert.base_tables.each do |db|
      @edit[:dbs][db] = ui_lookup(:model=>db)
    end
    @embedded = true
    @in_a_form = true
    @edit[:current][:add] = true if @edit[:alert_id].nil?         # Force changed to be true if adding a record
    session[:changed] = (@edit[:new] != @edit[:current])
  end

  def alert_default_repeat_time
    (@edit[:new][:expression][:eval_method] && @edit[:new][:expression][:eval_method] == "hourly_performance") ||
      @edit[:new][:exp_event] == "_hourly_timer_" ?
      1.hour.to_i : 10.minutes.to_i
  end

  def alert_get_perf_column_unit(val)
    return nil unless val
    e_point = val.rindex(')')
    s_point = val.rindex('(')
    res = e_point && s_point ? "#{val[s_point+1..e_point-1]} " : nil
    return res
  end

  def alert_build_snmp_variables
    @edit[:new][:snmp][:snmp_version] = "v1" if @edit[:new][:snmp][:snmp_version].blank?
    @edit[:snmp_var_types] = MiqSnmp.available_types
    @edit[:new][:snmp][:variables] ||= Array.new
    10.times do |i|
      @edit[:new][:snmp][:variables][i] ||= Hash.new
      @edit[:new][:snmp][:variables][i][:oid] ||= ""
      @edit[:new][:snmp][:variables][i][:var_type] ||= "<None>"
      @edit[:new][:snmp][:variables][i][:value] ||= ""
    end
  end

  def alert_build_blank_exp
    @edit[:expression] ||= Hash.new                                     # Create hash for this expression, if needed
    @edit[:expression][:expression] = Array.new                         # Store exps in an array
    @edit[:expression][:exp_idx] = 0                                    # Start at first exp
    @edit[:expression][:expression] = {"???"=>"???"}                    # Set as new exp element
    @edit[:new][:expression] = copy_hash(@edit[:expression][:expression]) # Copy to new exp
    @edit[:expression_table] = @edit[:expression][:expression] == {"???"=>"???"} ? nil : exp_build_table(@edit[:expression][:expression])

    @expkey = :expression                                               # Set expression key to expression
    exp_array(:init, @edit[:expression][:expression])                   # Initialize the exp array
    @edit[:expression][:exp_table] = exp_build_table(@edit[:expression][:expression])
    @edit[:expression][:exp_model] = @edit[:new][:db]                   # Set model for the exp editor
  end

  def alert_build_exp_options_info
    MiqAlert.expression_options(@edit[:new][:expression][:eval_method]).each do |eo|
      case eo[:name]

      when :ems_id
        # Handle missing or blank ems id
        unless !@alert.expression ||
                ExtManagementSystem.exists?(@edit[:new][:expression][:options][:ems_id].to_i)
          @edit[:new][:expression][:options][:ems_id] = nil
          @edit[:new][:expression][:options][:ems_alarm_mor] = nil
        end
        if @edit[:emss].length == 1 # Set to first column if only 1 choice
          @edit[:new][:expression][:options][:ems_id] ||= @edit[:emss].invert.to_a.first.last
          @edit[:ems_alarms] = alert_build_ems_alarms
        end

      when :perf_column
        @edit[:new][:expression][:options][:perf_column] ||= eo[:values][@edit[:new][:db]].invert.sort[0].last  # Set to first column
        @edit[:perf_column_options] = eo[:values][@edit[:new][:db]]     #storing perf_column values in hash to use them later for lookup to show units in UI
        @edit[:perf_column_unit] = alert_get_perf_column_unit(@edit[:perf_column_options][@edit[:new][:expression][:options][:perf_column]])
      when :value_threshold
        @edit[:new][:expression][:options][:value_threshold] ||= "" # Init value to blank
      when :trend_direction
        @edit[:new][:expression][:options][:trend_direction] ||= "none"
        @edit[:new][:expression][:options][:trend_steepness] ||= nil

      when :hdw_attr
        @edit[:hdw_attrs] = eo[:values].invert.sort
        @edit[:new][:expression][:options][:hdw_attr] ||= @edit[:hdw_attrs].first.last

      when :operator
        @edit[:operators] = eo[:values]
        @edit[:new][:expression][:options][:operator] ||= eo[:values].first

      when :event_log_message_filter_type
        @edit[:event_log_message_filter_types] = eo[:values]
        @edit[:new][:expression][:options][:event_log_message_filter_type] ||= eo[:values].first

      when :debug_trace
        @edit[:new][:expression][:options][:debug_trace] ||= "false"

      end
    end
  end

  def alert_build_pulldowns
    @sb[:alert] ||= Hash.new

    # :event_types
    unless @sb[:alert][:events] # Only create this once
      vm_events = MiqAlert.expression_options("event_threshold").find{|eo|eo[:name]==:event_types}[:values] # Get the allowed events
      @sb[:alert][:events] ||= Hash.new
      TL_ETYPE_GROUPS.each do |k,v|
        name = v[:name]
        v[:detail].each do |d|
          @sb[:alert][:events][d] = name + ": " + d if vm_events.include?(d)
        end
        v[:critical].each do |c|
          @sb[:alert][:events][c] = name + ": " + c if vm_events.include?(c)
        end
      end
    end

    # :time_thresholds
    @sb[:alert][:time_thresholds] ||= {
      5.minutes.to_i=>"5 Minutes", 10.minutes.to_i=>"10 Minutes", 15.minutes.to_i=>"15 Minutes", 30.minutes.to_i=>"30 Minutes",
      1.hour.to_i=>"1 Hour", 2.hours.to_i=>"2 Hours", 3.hours.to_i=>"3 Hours", 4.hours.to_i=>"4 Hours", 6.hours.to_i=>"6 Hours", 12.hours.to_i=>"12 Hours",
      1.day.to_i=>"1 Day"
# Stopping this at 1 day for now - Sprint 53
#     , 2.days.to_i=>"2 Days", 3.days.to_i=>"3 Days", 4.days.to_i=>"4 Days", 5.days.to_i=>"5 Days", 6.days.to_i=>"6 Days",
#     1.week.to_i=>"1 Week", 2.weeks.to_i=>"2 Weeks", 3.weeks.to_i=>"3 Weeks",
#     1.month.to_i=>"1 Month", 2.months.to_i=>"2 Months", 3.months.to_i=>"3 Months", 6.months.to_i=>"6 Months",
#     1.year.to_i=>"1 Year"
    }

    # :hourly_time_thresholds
    @sb[:alert][:hourly_time_thresholds] ||= {
      1.hour.to_i=>"1 Hour", 2.hours.to_i=>"2 Hours", 3.hours.to_i=>"3 Hours", 4.hours.to_i=>"4 Hours", 6.hours.to_i=>"6 Hours", 12.hours.to_i=>"12 Hours",
      1.day.to_i=>"1 Day"
    }

    # :rt_time_thresholds
    @sb[:alert][:rt_time_thresholds] ||= {
      1.minutes.to_i=>"1 Minute", 2.minutes.to_i=>"2 Minutes", 3.minutes.to_i=>"3 Minutes", 4.minutes.to_i=>"4 Minutes",
      5.minutes.to_i=>"5 Minutes", 10.minutes.to_i=>"10 Minutes", 15.minutes.to_i=>"15 Minutes", 30.minutes.to_i=>"30 Minutes",
      1.hour.to_i=>"1 Hour", 2.hours.to_i=>"2 Hours"
# Stopping this at 2 hours now - Sprint 65
#     , 3.hours.to_i=>"3 Hours", 4.hours.to_i=>"4 Hours", 6.hours.to_i=>"6 Hours", 12.hours.to_i=>"12 Hours",
#     1.day.to_i=>"1 Day"
    }

    # hourly_performance repeat times for Notify Every pull down
    @sb[:alert][:hourly_repeat_times] ||= {
      1.hour.to_i=>"1 Hour", 2.hours.to_i=>"2 Hours", 3.hours.to_i=>"3 Hours", 4.hours.to_i=>"4 Hours", 6.hours.to_i=>"6 Hours", 12.hours.to_i=>"12 Hours",
      1.day.to_i=>"1 Day"
    }

    # repeat times for Notify Every pull down
    @sb[:alert][:repeat_times] ||= {
      1.minutes.to_i=>"1 Minute", 2.minutes.to_i=>"2 Minutes", 3.minutes.to_i=>"3 Minutes", 4.minutes.to_i=>"4 Minutes",
      5.minutes.to_i=>"5 Minutes", 10.minutes.to_i=>"10 Minutes", 15.minutes.to_i=>"15 Minutes", 30.minutes.to_i=>"30 Minutes",
      1.hour.to_i=>"1 Hour", 2.hours.to_i=>"2 Hours", 3.hours.to_i=>"3 Hours", 4.hours.to_i=>"4 Hours", 6.hours.to_i=>"6 Hours", 12.hours.to_i=>"12 Hours",
      1.day.to_i=>"1 Day"
    }
  end

  def alert_build_ems_alarms
    alarms = Hash.new
    begin
    alarms = MiqAlert.ems_alarms(@edit[:new][:db], @edit[:new][:expression][:options][:ems_id])
    rescue StandardError => bang
      add_flash(_("Error during '%s': ") % "ems_alarms" << bang.message, :error)
    end
    return alarms
  end

  # Set alert record variables to new values
  def alert_set_record_vars(alert)
    alert.description = @edit[:new][:description]
    alert.enabled = @edit[:new][:enabled]
    alert.db = @edit[:new][:db]
    unless @edit[:new][:expression][:eval_method]
      alert.expression = @edit[:new][:expression]["???"] ? nil : MiqExpression.new(@edit[:new][:expression])
      if @edit[:new][:exp_event] == "_hourly_timer_"
        alert.responds_to_events = @edit[:new][:exp_event]
      else
        alert.responds_to_events = @edit[:new][:exp_event] && @edit[:new][:exp_event] > 0 ?
                                    MiqEvent.find(@edit[:new][:exp_event]).name : nil
      end
    else
      alert.expression = copy_hash(@edit[:new][:expression])
      # nothing acts like an expression, exp event is needed
      if @edit[:new][:expression][:eval_method] == "nothing"
        if @edit[:new][:exp_event] == "_hourly_timer_"
          alert.responds_to_events = @edit[:new][:exp_event]
        else
          alert.responds_to_events = @edit[:new][:exp_event] && @edit[:new][:exp_event] > 0 ?
                                      MiqEvent.find(@edit[:new][:exp_event]).name : nil
        end
      end
    end
    alert.options = Hash.new
    alert.options[:notifications] = Hash.new
    alert.options[:notifications][:delay_next_evaluation] = @edit[:new][:repeat_time]
    alert.options[:notifications][:email] = copy_hash(@edit[:new][:email]) if @edit[:new][:send_email]
    if @edit[:new][:send_snmp]
      #delete any blank entries from host array
      @edit[:new][:snmp][:host].delete_if {|x| x.nil? || x == "" }
      alert.options[:notifications][:snmp] = copy_hash(@edit[:new][:snmp])
    end
    alert.options[:notifications][:snmp] = copy_hash(@edit[:new][:snmp]) if @edit[:new][:send_snmp]
    alert.options[:notifications][:evm_event] = {} if @edit[:new][:send_evm_event]  # Set as empty hash, no parms needed
    alert.options[:notifications][:automate] = {:event_name=>@edit[:new][:event_name]} if @edit[:new][:send_event]
  end

  # Check alert record variables
  def alert_valid_record?(alert)
    if alert.expression.nil?
      add_flash(_("A valid expression must be present"), :error)
    end
    unless @edit[:new][:expression][:eval_method] && @edit[:new][:expression][:eval_method] != "nothing"
      add_flash(_("%s must be selected") % "A Driving Event", :error) if alert.responds_to_events.blank?
    end
    if alert.options[:notifications][:automate]
      add_flash(_("%s is required") % "Event Name", :error) if alert.options[:notifications][:automate][:event_name].blank?
    end
    if @edit.fetch_path(:new, :expression, :eval_method) == "realtime_performance"
      vt = @edit.fetch_path(:new, :expression, :options, :value_threshold)
      unless vt && is_integer?(vt)
        add_flash(_("%s must be an integer") % "Value Threshold", :error)
      end
      if @edit.fetch_path(:new, :expression, :options, :trend_direction).ends_with?("more_than")
        ts = @edit.fetch_path(:new, :expression, :options, :trend_steepness)
        unless ts && is_integer?(ts)
          add_flash(_("%s must be an integer") % "Trend Steepness", :error)
        end
      end
    end
    unless alert.options[:notifications][:email] ||
            alert.options[:notifications][:snmp] ||
            alert.options[:notifications][:evm_event] ||
            alert.options[:notifications][:automate]
      add_flash(_("At least one %s must be configured") % "of E-mail, SNMP Trap, Timeline Event, or Management Event",
                :error)
    end
    if alert.options[:notifications][:email]
      add_flash(_("At least one %s must be configured") % "E-mail recipient", :error) if alert.options[:notifications][:email][:to].blank?
    end
    if alert.options[:notifications][:snmp]
      validate_snmp_options(alert.options[:notifications][:snmp])
      unless @flash_array
        temp = Array.new
        @edit[:new][:snmp][:variables].each_with_index do |var,i|
          unless var[:oid].blank?
            temp.push(var)
          end
        end
        alert.options[:notifications][:snmp][:variables] = temp
      end
    end
    return @flash_array == nil
  end

  # Get information for an alert
  def alert_get_info(alert)
    @record = @alert = alert
    @temp[:email_to] = Array.new
    if @alert.responds_to_events == "_hourly_timer_"
      @temp[:event] = "Hourly Timer"
    else
      e = MiqEvent.find_by_name(@alert.responds_to_events)
      @temp[:event] = e.nil? ? "<No Event configured>" : e.etype.description + ": " + e.description
    end
    if @alert.options && @alert.options[:notifications] && @alert.options[:notifications][:email] && @alert.options[:notifications][:email][:to]
      @alert.options[:notifications][:email][:to].each_with_index do |e, e_idx|
        u = User.find_by_email(e)
        @temp[:email_to].push(u ? "#{u.name} (#{e})" : e)
      end
    end
    @right_cell_text = _("%{model} \"%{name}\"") % {:model=>ui_lookup(:model=>"MiqAlert"), :name=>alert.description}
    @right_cell_div = "alert_details"

    @record = @alert
    @expression_table = exp_build_table(@alert.expression.exp) if @alert.expression.is_a?(MiqExpression)

    if x_active_tree == :alert_tree
      @alert_profiles = @alert.memberof.sort{|a,b|a.description.downcase<=>b.description.downcase}
    end

    unless @alert.expression.is_a?(MiqExpression) # Get the EMS if it's in the expression
      @temp[:ems] = ExtManagementSystem.find_by_id(@alert.expression[:options][:ems_id].to_i)
    end
    if @alert.expression.kind_of?(Hash) && @alert.expression[:eval_method]
      MiqAlert.expression_options(@alert.expression[:eval_method]).each do |eo|
        case eo[:name]
        when :perf_column
          @temp[:perf_column_unit] = alert_get_perf_column_unit(eo[:values][@alert.db][@alert.expression[:options][:perf_column]])
        end
      end
    end
  end

  def alert_build_tree(type=:alert, name=:alert_tree)
    x_tree_init(name, type, 'MiqAlert', :full_ids => true)
    tree_nodes = x_build_dynatree(x_tree(name))

    # Fill in root node details
    root = tree_nodes.first
    root[:title] = "All Alerts"
    root[:tooltip] = "All Alerts"
    root[:icon] = "folder.png"

    @temp[name] = tree_nodes.to_json  # JSON object for tree loading
    x_node_set(tree_nodes.first[:key], name) unless x_node(name)    # Set active node to root if not set
  end

end
