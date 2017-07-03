class PrincePdfGenerator < PdfGenerator
  include Vmdb::Logging
  def self.executable
    return @executable if defined?(@executable)
    @executable = `which prince`.chomp
  end

  def self.available?
    !executable.blank?
  end

  def executable
    self.class.executable
  end

  def pdf_from_string(html_string, stylesheet)
    options = {
      :params  => {
        :input  => "html",
        :style  => processed_stylesheet(stylesheet),
        :log    => Rails.root.join("log", "prince.log"),
        :output => "-", # Write to stdout
        "-"     => nil  # Read from stdin
      },
      :in_data => html_string
    }

    require 'awesome_spawn'
    _log.debug do
      command = AwesomeSpawn.build_command_line(executable, options[:params])
      "Executing: #{command}"
    end
    AwesomeSpawn.run!(executable, options).output
  end

  private

  # Writes the stylesheet Sprocket::Asset to a file and returns the path
  # Relies on the digest_path to keep the file fresh
  #
  def processed_stylesheet(stylesheet_path)
    AssetWriter.new(stylesheet_path, 'tmp/cache/pdf').write
  end
end
