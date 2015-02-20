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
    Tempfile.open('miqini') do |tf|
      tf.write(content)
      tf.close
      IniFile.load(tf.path)
    end
  rescue IniFile::Error
    raise "Invalid file contents detected"
  end

  def validate_sysprep_xml
    name = Nokogiri::XML(content).root.try(:name)
    raise "Invalid file contents detected" unless name == "unattend"
  end
end
