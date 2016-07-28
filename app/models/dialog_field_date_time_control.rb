class DialogFieldDateTimeControl < DialogFieldDateControl
  AUTOMATE_VALUE_FIELDS = %w(show_past_dates read_only visible).freeze

  def automate_output_value
    return nil if @value.blank?
    with_current_user_timezone { Time.zone.parse(@value).utc.iso8601 }
  end

  def value
    @value = dynamic ? values_from_automate : default_time if @value.blank?

    Time.parse(@value).strftime("%m/%d/%Y %H:%M")
  end

  def refresh_json_value
    @value = values_from_automate

    date_time_value = with_current_user_timezone { Time.parse(@value) }

    {
      :date      => date_time_value.strftime("%m/%d/%Y"),
      :hour      => date_time_value.strftime("%H"),
      :min       => date_time_value.strftime("%M"),
      :read_only => read_only?,
      :visible   => visible?
    }
  end

  private

  def default_time
    with_current_user_timezone { Time.zone.now + 1.day }.strftime("%m/%d/%Y %H:%M")
  end
end
