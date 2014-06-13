module MiqReport::Formatters::Pdf
  def to_pdf
    ReportFormatter::ReportRenderer.render(:pdf) do |e|
      e.options.mri = self # set the MIQ_Report instance in the formatter
    end
  end

  def to_pdf_simpletable
    ReportFormatter::ReportRenderer.render(:pdf_simpletable) do |e|
      e.options.mri = self # set the MIQ_Report instance in the formatter
    end
  end
end
