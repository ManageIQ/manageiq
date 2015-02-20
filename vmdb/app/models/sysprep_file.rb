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
    raise err, "Invalid INI file contents detected. #{err.message}", err.backtrace
  end

  def validate_sysprep_xml
    name = Nokogiri::XML(content).root.try(:name)
    raise "Invalid XML file contents detected." unless name == "unattend"
  end
end
