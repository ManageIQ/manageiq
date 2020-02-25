class MiqWidget::ChartContent < MiqWidget::ContentGeneration
  def generate(user_or_group)
    theme = user_or_group.settings.fetch_path(:display, :reporttheme) if user_or_group.kind_of?(User)

    # TODO: default reporttheme to MIQ since it doesn't look like we ever change it
    theme ||= "MIQ"

    report.to_chart(theme, false, MiqReport.graph_options)
    ManageIQ::Reporting::Charting.serialized(report.chart)
  end
end
