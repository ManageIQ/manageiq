class MiqProvisionWorkflow < MiqRequestWorkflow
  SUBCLASSES = %w{
    MiqProvisionVirtWorkflow
  }

  def self.class_for_platform(platform)
    "MiqProvision#{platform.titleize}Workflow".constantize
  end

  def self.class_for_source(source_or_id)
    source = source_or_id.kind_of?(ActiveRecord) ? source_or_id : VmOrTemplate.find_by_id(source_or_id)
    return nil if source.nil?
    class_for_platform(source.class.model_suffix)
  end

  # TODO: Move this out, only called by app/controllers/application_controller/sysprep_answer_file.rb
  def self.validate_sysprep_file(io_handle)
    require 'inifile'

    begin
      text = io_handle.read
      if text.include?("<?xml")
        xml = MiqXml.load(text)
        raise "Invalid file contents detected" if xml.root.name != "unattend"
      else
        Tempfile.open('miqini') do |tf|
          tf.write(text)
          tf.close()
          IniFile.load(tf.path)
        end
      end
      return text
    rescue StandardError, IniFile::Error
      raise "Invalid file contents detected"
    end
    return nil
  end
end

# Preload any subclasses of this class, so that they will be part of the
#   conditions that are generated on queries against this class.
MiqProvisionWorkflow::SUBCLASSES.each { |c| require_dependency Rails.root.join("app", "models", "#{c.underscore}.rb").to_s }
