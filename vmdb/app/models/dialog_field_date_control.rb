class DialogFieldDateControl < DialogField

  include TimezoneMixin

  def show_past_dates
    self.options[:show_past_dates] || false
  end

  def show_past_dates=(value)
    self.options[:show_past_dates] = value
  end

  def automate_output_value
    Date.parse(self.value).iso8601
  end

  def default_time
    with_current_user_timezone { Time.zone.now + 1.day }
  end

  def default_value
    default_time.strftime("%m/%d/%Y")
  end
end
