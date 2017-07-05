module AlertMixin
  def event_log_threshold?(options)
    unless respond_to?(:event_logs)
      raise _("%{class_name} expected to respond to event_logs and doesn't!") % {:class_name => self.class.name}
    end
    raise _("option :message_filter_type is required") unless options[:message_filter_type]
    raise _("option :message_filter_value is required") unless options[:message_filter_value]

    allowed_types = %w(STARTS\ WITH ENDS\ WITH INCLUDES REGULAR\ EXPRESSION)
    unless allowed_types.include?(options[:message_filter_type])
      raise _("option :message_filter_type: %{options}, invalid, expected one of %{type}") %
              {:options => options[:message_filter_type], :type => allowed_types}
    end

    options.reverse_merge!({:time_threshold => 10.days, :freq_threshold => 2})

    _log.info("options: #{options.inspect}")

    cond, sel = build_conditions_and_selects(options)
    logs = operating_system.nil? ? [] : operating_system.event_logs.where(cond).select(sel)

    _log.info("Found [#{logs.length}], conditions: #{cond.inspect}")

    logs = case options[:message_filter_type]
           when "STARTS WITH" then          logs.find_all { |l| l.message.to_s.starts_with?(options[:message_filter_value]) }
           when "ENDS WITH" then            logs.find_all { |l| l.message.to_s.ends_with?(options[:message_filter_value]) }
           when "INCLUDES" then            logs.find_all { |l| l.message.to_s.include?(options[:message_filter_value]) }
           when "REGULAR EXPRESSION" then  logs.find_all { |l| l.message.to_s =~ options[:message_filter_value] }
           else
             logs
           end

    _log.info("After filtering: [#{logs.length}], filter: #{options[:message_filter_type]} #{options[:message_filter_value]}...Checking freq_threshold: #{options[:freq_threshold]}")
    logs.length >= options[:freq_threshold].to_i
  end

  def build_conditions_and_selects(options)
    cond = [""]
    sel = "message"
    if options[:time_threshold]
      sel_conj = sel.empty? ? "" : ", "
      sel << "#{sel_conj}generated"
      cond[0] << "generated >= ?"
      cond << options[:time_threshold].to_i.seconds.ago.utc
    end

    [:source, :event_id, :level, :name].each do |col|
      if options[col]
        sel_conj = sel.empty? ? "" : ", "
        sel << "#{sel_conj}#{col}"
        conjunction = cond[0].empty? ? "" : " and "
        cond[0] << "#{conjunction}#{col} = ?"
        cond << options[col]
      end
    end
    return cond, sel
  end
end
