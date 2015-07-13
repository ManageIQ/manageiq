module MiqReport::Formatters::Timeline
  def to_timeline
    ReportFormatter::ReportRenderer.render(:timeline) do |e|
      e.options.mri = self # set the MIQ_Report instance in the formatter
    end
  end
end
