class PrincePdfGenerator < PdfGenerator
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
        :input    => "html",
        :style    => stylesheet,
        :fileroot => Rails.public_path,
        :log      => Rails.root.join("log/prince.log"),
        :output   => "-", # Write to stdout
        "-"       => nil  # Read from stdin
      },
      :in_data => html_string
    }

    require 'awesome_spawn'
    if $log.debug?
      command = AwesomeSpawn.build_command_line(executable, options[:params])
      $log.debug "MIQ(#{self.class.name}##{__method__}) Executing: #{command}"
    end
    AwesomeSpawn.run!(executable, options).output
  end
end
