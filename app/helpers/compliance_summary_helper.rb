module ComplianceSummaryHelper
  def textual_group_compliance
    %i(compliance_status compliance_history)
  end

  def textual_compliance_status
    h = {:label => _("Status")}
    if @record.number_of(:compliances) == 0
      h[:value] = _("Never Verified")
    else
      compliant = @record.last_compliance_status
      date      = @record.last_compliance_timestamp
      h[:image] = "100/#{compliant ? "check" : "x"}.png"
      h[:value] = if !compliant
                    _("Non-Compliant as of %{time} Ago") %
                    {:time => time_ago_in_words(date.in_time_zone(Time.zone)).titleize}
                  else
                    _("Compliant as of %{time} Ago") %
                    {:time => time_ago_in_words(date.in_time_zone(Time.zone)).titleize}
                  end
      h[:title] = _("Show Details of Compliance Check on %{date}") % {:date => format_timezone(date)}
      h[:explorer] = true if @explorer
      h[:link] = url_for(
        :controller => controller.controller_name,
        :action     => 'show',
        :id         => @record,
        :display    => 'compliance_history', :count => 1
      )
    end
    h
  end

  def textual_compliance_history(options_if_available = {})
    h = {:label => _("History")}
    if @record.number_of(:compliances) == 0
      h[:value] = _("Not Available")
    else
      h[:image] = "100/compliance.png"
      h[:value] = _("Available")
      h[:title] = _("Show Compliance History of this %{model} (Last 10 Checks)") %
                  {:model => ui_lookup(:model => controller.class.model.name)}
      h[:explorer] = true if @explorer
      h[:link] = url_for(
        :controller => controller.controller_name,
        :action     => 'show',
        :id         => @record,
        :display    => 'compliance_history')
      h.merge!(options_if_available)
    end
    h
  end
end
