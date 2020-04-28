module MiqReport::Formatters::Text
  def to_text
    ManageIQ::Reporting::Formatter::ReportRenderer.render(:text) do |e|
      e.options.mri = (self) # set the MIQ_Report instance in the formatter
      e.options.ignore_table_width = true
    end
  end
  alias_method :to_txt, :to_text
end
