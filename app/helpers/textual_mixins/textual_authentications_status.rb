module TextualMixins::TextualAuthenticationsStatus
  def textual_time_ago(time)
    if time
      time_str = time_ago_in_words(time.in_time_zone(Time.zone)).titleize
      _("%{time} Ago") % { :time => time_str }
    else
      _("Never")
    end
  end

  def textual_authentication_value(status, updated_on, valid_str = _("Valid"))
    return _("None") unless status
    _("%{status} - %{time}") % { :status => status == "Valid" ? valid_str : status,
                                 :time   => textual_time_ago(updated_on) }
  end

  def textual_authentication_title(status, updated_on, last_valid_on)
    if status == "Valid"
      _("Updated - %{time}") % { :time => textual_time_ago(updated_on) }
    else
      times = { :update_time => textual_time_ago(updated_on),
                :valid_time  => textual_time_ago(last_valid_on) }
      _("Updated - %{update_time}, Last valid connection - %{valid_time}") % times
    end
  end

  def map_authentications(authentications)
    authentications.map do |auth|
      { :label => _("%{label} Authentication") % { :label => auth.authtype.to_s.titleize },
        :value => textual_authentication_value(auth.status, auth.updated_on),
        :title => textual_authentication_title(auth.status, auth.updated_on, auth.last_valid_on) }
    end
  end

  def textual_authentications_status
    authentications = @ems.authentications.order(:authtype).collect
    return [{ :label => _("%{label} Authentication") % { :label => @ems.default_authentication_type.to_s.titleize },
              :title => t = _("None"),
              :value => t }] if authentications.blank?

    map_authentications(authentications)
  end
end
