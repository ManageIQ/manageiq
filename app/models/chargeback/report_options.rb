class Chargeback
  # ReportOptions are usualy stored in MiqReport.db_options[:options]
  ReportOptions = Struct.new(
    :interval,             # daily | weekly | monthly
    :interval_size,
    :end_interval_offset,
    :owner,                # userid
    :tenant_id,
    :tag,                  # like /managed/environment/prod (Mutually exclusive with :user)
    :provide_id,
    :entity_id,            # 1/2/3.../all rails id of entity
    :service_id,
    :groupby,
    :groupby_tag,
    :userid,
    :ext_options,
  ) do
    def self.new_from_h(hash)
      new(*hash.values_at(*members))
    end

    def initialize(*)
      super
      self.interval ||= 'daily'
      self.end_interval_offset ||= 0
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
        start_time = (ts - start_interval_offset.days).beginning_of_day.utc
        end_time   = (ts - end_interval_offset.days).end_of_day.utc
      when 'weekly'
        start_time = (ts - start_interval_offset.weeks).beginning_of_week.utc
        end_time   = (ts - end_interval_offset.weeks).end_of_week.utc
      when 'monthly'
        start_time = (ts - start_interval_offset.months).beginning_of_month.utc
        end_time   = (ts - end_interval_offset.months).end_of_month.utc
      else
        raise _("interval '%{interval}' is not supported") % {:interval => interval}
      end

      start_time..end_time
    end
  end
end
