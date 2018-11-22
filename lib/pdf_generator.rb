class PdfGenerator
  def self.new
    self == PdfGenerator ? detect_available_generator.new : super
  end

  def self.instance
    @instance ||= self.new
  end

  def self.pdf_from_string(html_string, stylesheet)
    instance.pdf_from_string(sanitize_html(html_string), stylesheet_file_path(stylesheet))
  end

  def self.available?
    instance.available?
  end

  # Convert `html_string` to pdf using the given css `stylesheet`
  #
  # @param [String] html_string The HTML content to be converted to pdf
  # @param [String] stylesheet File name (without extension) of the css
  #   stylesheet to be used
  # @return [String] The pdf file contents
  def pdf_from_string(_html_string, _stylesheet)
    raise NotImplementedError, "must be implemented in a subclass"
  end

  def available?
    self.class.available?
  end

  def self.detect_available_generator
    self.subclasses.detect(&:available?) || NullPdfGenerator
  end
  private_class_method :detect_available_generator

  def self.sanitize_html(html_string)
    # strip out bad attachment_fu URLs
    # and remove asset ids on images
    html_string.gsub('.com:/', '.com/')
      .gsub(/src=["'](\S+)\?\d*["']/i, 'src="\1"')
  end
  private_class_method :sanitize_html

  # Find stylesheet asset with short path and return filesystem path
  #
  def self.stylesheet_file_path(stylesheet)
    Rails.root.join('lib', 'pdf_generator', stylesheet).to_s
  end

  private_class_method :stylesheet_file_path
end

# Dynamically load all plugins
Dir.glob(File.join(File.dirname(__FILE__), "pdf_generator/*.rb")).each { |f| require_dependency f }
