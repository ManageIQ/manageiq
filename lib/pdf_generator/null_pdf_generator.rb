class NullPdfGenerator < PdfGenerator
  def self.available?
    false
  end

  def pdf_from_string(_html_string, _stylesheet)
    raise NotImplementedError, "pdf generation is not available"
  end
end
