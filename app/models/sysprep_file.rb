class SysprepFile
  attr_reader :content

  def initialize(content)
    @content = content.respond_to?(:read) ? content.read : content
    validate_content
  end

  private

  def validate_content
    send("validate_sysprep_#{content.include?("<?xml") ? "xml" : "ini"}")
  end

  def validate_sysprep_ini
    require 'inifile'
    IniFile.new(:content => content)
  rescue IniFile::Error => err
    raise err,
          _("Invalid INI file contents detected. %{error_message}") % {:error_message => err.message},
          err.backtrace
  end

  def validate_sysprep_xml
    name = Nokogiri::XML(content).root.try(:name)
    raise _("Invalid XML file contents detected.") unless name == "unattend"
  end
end
