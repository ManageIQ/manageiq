class PrincePdfGenerator < PdfGenerator
  include Vmdb::Logging
  def self.executable
    return @executable if defined?(@executable)
    @executable = `which prince 2> /dev/null`.chomp
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
        :style  => stylesheet,
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
end
