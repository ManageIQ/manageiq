module ReportHelper
  Timer = Struct.new(
    :typ,
    :months,
    :weeks,
    :days,
    :hours,
    :start_date,
    :start_hour,
    :start_min,
  ) do
    def initialize(typ = nil, months = 1, weeks = 1, days = 1, hours = 1, start_date = nil, start_hour = '00',
                   start_min = '00')
      super
    end

    def update_from_hash(params)
      self.typ = params[:timer_typ] if params[:timer_typ]
      self.months = params[:timer_months] if params[:timer_months]
      self.weeks = params[:timer_weeks] if params[:timer_weeks]
      self.days = params[:timer_days] if params[:timer_days]
      self.hours = params[:timer_hours] if params[:timer_hours]
      self.start_date = params[:miq_date_1] if params[:miq_date_1]
      self.start_hour = params[:start_hour] if params[:start_hour]
      self.start_min = params[:start_min] if params[:start_min]
      if params[:time_zone]
        t = Time.now.in_time_zone(params[:timezone]) + 1.day # Default date/time to tomorrow in selected time zone
        self.start_date = "#{t.month}/#{t.day}/#{t.year}" # Reset the start date
        self.start_hour = '00' # Reset time to midnight
        self.start_min = '00'
      end
    end

    def update_from_miq_schedule(run_at, timezone)
      self.typ    = run_at[:interval][:unit].titleize
      self.months = run_at[:interval][:value] if run_at[:interval][:unit] == 'monthly'
      self.weeks  = run_at[:interval][:value] if run_at[:interval][:unit] == 'weekly'
      self.days   = run_at[:interval][:value] if run_at[:interval][:unit] == 'daily'
      self.hours  = run_at[:interval][:value] if run_at[:interval][:unit] == 'hourly'
      t = run_at[:start_time].utc.in_time_zone(timezone)
      self.start_hour = t.strftime("%H")
      self.start_min = t.strftime("%M")
      self.start_date = "#{t.month}/#{t.day}/#{t.year}"
    end

    def flush_to_miq_schedule(run_at, timezone)
      run_at ||= {}
      run_at[:start_time] = "#{start_time_in_utc(timezone)} Z"
      run_at[:tz]         = timezone
      run_at[:interval] ||= {}
      run_at[:interval][:unit] = typ.downcase
      case typ.downcase
      when 'monthly'
        run_at[:interval][:value] = months
      when 'weekly'
        run_at[:interval][:value] = weeks
      when 'daily'
        run_at[:interval][:value] = days
      when 'hourly'
        run_at[:interval][:value] = hours
      else
        run_at[:interval].delete(:value)
      end
      run_at
    end

    private

    def start_time_in_utc(timezone)
      create_time_in_utc("#{start_date} #{start_hour}:#{start_min}:00", timezone)
    end
  end

  class Timer
    include Mixins::TimeHelper
  end
end
