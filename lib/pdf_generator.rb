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
  def pdf_from_string(html_string, stylesheet)
    raise NotImplementedError, "must be implemented in a subclass"
  end

  def available?
    self.class.available?
  end

  private

  def self.detect_available_generator
    self.subclasses.detect(&:available?) || NullPdfGenerator
  end

  def self.sanitize_html(html_string)
    # strip out bad attachment_fu URLs
    html_string.gsub('.com:/', '.com/').
      # remove asset ids on images
      gsub(/src=["'](\S+)\?\d*["']/i, 'src="\1"')
  end

  def self.stylesheet_file_path(stylesheet)
    # Determine path relative to Rails.public_path
    "/../app/assets/stylesheets/#{stylesheet}.css"
  end
end

# Dynamically load all plugins
Dir.glob(File.join(File.dirname(__FILE__), "pdf_generator/*.rb")).each { |f| require_dependency f }
