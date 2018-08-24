class Chargeback
  # ReportOptions are usualy stored in MiqReport.db_options[:options]
  ReportOptions = Struct.new(
    :interval,             # daily | weekly | monthly
    :interval_size,        # number of :intervals in the report (i.e. `12` months, `4` weeks)
    :end_interval_offset,  # report ends :intervals ago (i.e. `3` months ago, or `2` weeks ago)
    :owner,                # userid
    :tenant_id,
    :tag,                  # like /managed/environment/prod (Mutually exclusive with :user)
    :report_cols,          # cols visible in the final report
    :provide_id,
    :entity_id,            # 1/2/3.../all rails id of entity (ContainerProject or Vm)
    :service_id,
    :groupby,
    :groupby_tag,
    :groupby_label,
    :userid,
    :ext_options,
    :include_metrics,      # enable charging allocated resources with C & U
    :method_for_allocated_metrics,
    :group_by_tenant?,
    :group_by_date_only?,
    :cumulative_rate_calculation,
  ) do
    def self.new_from_h(hash)
      new(*hash.values_at(*members))
    end

    # skip metric value field because we don't want
    # to accumulate metric values(only costs)
    def skip_field_accumulation?(field, value)
      return false if cumulative_rate_calculation? == false
      return false unless field.ends_with?("_metric") && value

      true
    end

    def cumulative_rate_calculation?
      !!self[:cumulative_rate_calculation]
    end

    ALLOCATED_METHODS_WHITELIST = %i(max avg current_value).freeze

    def method_for_allocated_metrics
      method = self[:method_for_allocated_metrics] || :max

      unless ALLOCATED_METHODS_WHITELIST.include?(method)
        raise "Invalid method for allocated calculations #{method}"
      end

      return :sum_of_maxes_from_grouped_values if method == :max && group_by_tenant?
      method
    end

    # include_metrics = nil is default value(true)
    def include_metrics?
      include_metrics.nil? || include_metrics
    end

    def initialize(*)
      super
      self.interval ||= 'daily'
      self.end_interval_offset ||= 0
      self.ext_options ||= {}
    end

    def tz
      # TODO: Support time profiles via options[:ext_options][:time_profile]
      @tz ||= Metric::Helper.get_time_zone(ext_options)
    end

    def report_time_range
      raise _("Option 'interval_size' is required") if interval_size.nil?

      start_interval_offset = (end_interval_offset + interval_size - 1)

      ts = Time.now.in_time_zone(tz)
      case interval
      when 'daily'
        start_time = (ts - start_interval_offset.days).beginning_of_day
        end_time   = (ts - end_interval_offset.days).end_of_day
      when 'weekly'
        start_time = (ts - start_interval_offset.weeks).beginning_of_week
        end_time   = (ts - end_interval_offset.weeks).end_of_week
      when 'monthly'
        start_time = (ts - start_interval_offset.months).beginning_of_month
        end_time   = (ts - end_interval_offset.months).end_of_month
      else
        raise _("interval '%{interval}' is not supported") % {:interval => interval}
      end

      start_time..end_time
    end

    def start_of_report_step(timestamp)
      ts = timestamp.in_time_zone(tz)
      case interval
      when 'daily'
        ts.beginning_of_day
      when 'weekly'
        ts.beginning_of_week
      when 'monthly'
        ts.beginning_of_month
      else
        raise _("interval '%{interval}' is not supported") % {:interval => interval}
      end
    end

    def report_step_range(timestamp)
      ts = timestamp.in_time_zone(tz)
      case interval
      when 'daily'
        [ts.beginning_of_day, ts.end_of_day, ts.strftime('%m/%d/%Y')]
      when 'weekly'
        s_ts = ts.beginning_of_week
        e_ts = ts.end_of_week
        [s_ts, e_ts, "Week of #{s_ts.strftime('%m/%d/%Y')}"]
      when 'monthly'
        s_ts = ts.beginning_of_month
        e_ts = ts.end_of_month
        [s_ts, e_ts, s_ts.strftime('%b %Y')]
      else
        raise _("interval '%{interval}' is not supported") % {:interval => interval}
      end
    end

    def duration_of_report_step
      case interval
      when 'daily'   then 1.day
      when 'weekly'  then 1.week
      when 'monthly' then 1.month
      end
    end

    def tenant_for(consumption)
      consumption.resource.tenant
    end

    def classification_for(consumption)
      tag = consumption.tag_names.find { |x| x.starts_with?(groupby_tag) } # 'department/*'
      tag = tag.split('/').second unless tag.blank? # 'department/finance' -> 'finance'
      tag_hash[tag]
    end

    def group_by_tenant?
      self[:groupby] == 'tenant'
    end

    def group_by_date_only?
      self[:groupby] == 'date-only'
    end

    private

    def tag_hash
      if groupby_tag
        @tag_hash ||= Classification.hash_all_by_type_and_name[groupby_tag][:entry]
      end
    end
  end
end
