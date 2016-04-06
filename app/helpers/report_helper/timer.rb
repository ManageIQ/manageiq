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
  end
end
