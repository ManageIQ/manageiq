module MiqReport::Formatters::Text
  def to_text
    ReportFormatter::ReportRenderer.render(:text) do |e|
      e.options.mri = (self) # set the MIQ_Report instance in the formatter
    end
  end
  alias_method :to_txt, :to_text
end
