class DialogFieldDateTimeControl < DialogFieldDateControl

  def automate_output_value
    with_current_user_timezone { Time.zone.parse(self.value).utc.iso8601 }
  end

  def default_value
    default_time.strftime("%m/%d/%Y %H:00")
  end

end
