module ReportsSpecHelper
  def render_report(report)
    ReportFormatter::ReportRenderer.render(Charting.format) do |e|
      e.options.mri           = report
      e.options.show_title    = true
      e.options.graph_options = MiqReport.graph_options(600, 400)
      e.options.theme         = 'miq'
      yield e if block_given?
    end
  end
end
