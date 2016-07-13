module TextualMixins::TextualMetricsStatus
  def textual_metrics_status
    return {
      :label => _("Last Metrics Collection"),
      :title => _("None"),
      :value => _("None")
    } unless @ems.last_metrics_update_date

    status        = (@ems.last_metrics_error || :valid).to_s.titleize
    updated_on    = @ems.last_metrics_update_date
    last_valid_on = @ems.last_metrics_success_date

    {
      :label => _("Last Metrics Collection"),
      :value => textual_authentication_value(status, updated_on, _("Success")),
      :title => textual_authentication_title(status, updated_on, last_valid_on)
    }
  end
end
