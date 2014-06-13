class NullPdfGenerator < PdfGenerator
  def self.available?
    false
  end

  def pdf_from_string(html_string, stylesheet)
    raise NotImplementedError, "pdf generation is not available"
  end
end
