module MiqReport::Formatters::Html
  def to_html
    ReportFormatter::ReportRenderer.render(:html) do |e|
      e.options.mri = self # set the MIQ_Report instance in the formatter
    end
  end
end
