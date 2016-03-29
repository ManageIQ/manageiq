module ComplianceSummaryHelper
  def textual_compliance_status
    h = {:label => _("Status")}
    if @record.number_of(:compliances) == 0
      h[:value] = _("Never Verified")
    else
      compliant = @record.last_compliance_status
      date      = @record.last_compliance_timestamp
      h[:image] = compliant ? "check" : "x"
      h[:value] = if !compliant
                    _("Non-Compliant as of %{time} Ago") %
                    {:time => time_ago_in_words(date.in_time_zone(Time.zone)).titleize}
                  else
                    _("Compliant as of %{time} Ago") %
                    {:time => time_ago_in_words(date.in_time_zone(Time.zone)).titleize}
                  end
      h[:title] = _("Show Details of Compliance Check on %{date}") % {:date => format_timezone(date)}
      h[:explorer] = true
      h[:link] = url_for(
        :controller => controller.controller_name,
        :action     => 'show',
        :id         => @record,
        :display    => 'compliance_history', :count => 1
      )
    end
    h
  end
end
