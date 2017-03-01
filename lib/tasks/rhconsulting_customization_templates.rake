# Author: George Goh <george.goh@redhat.com>
require_relative 'rhconsulting_illegal_chars'
require_relative 'rhconsulting_options'

class CustomizationTemplateImportExport
  class ParsedNonDialogYamlError < StandardError; end

  def import(filename)
    raise "Must supply filename or directory" if filename.blank?
    if File.file?(filename)
      customization_templates = YAML.load_file(filename)
      import_customization_templates(customization_templates)
    elsif File.directory?(filename)
      Dir.glob("#{filename}/*.yaml") do |fname|
        customization_templates = YAML.load_file(fname)
        import_customization_templates(customization_templates)
      end
    else
      raise "Argument is not a filename or directory"
    end
  end

  def export(filename, options = {})
    raise "Must supply filename or directory" if filename.blank?
    begin
      file_type = File.ftype(filename)
    rescue
      # If we get an error back assume it is a filename that does not exist
      file_type = 'file'
    end

    customization_templates_array = export_customization_templates(CustomizationTemplate.where("system is not true").order(:id).all)

    if file_type == 'file'
      File.write(filename, customization_templates_array.to_yaml)
    elsif file_type == 'directory'
      customization_templates_array.each do |template_hash|
        # Get the description to use in the filename
        name = "#{template_hash["name"]}"

        # Replace invalid filename characters
        name = MiqIllegalChars.replace(name, options)
        fname = "#{filename}/#{name}.yaml"

        File.write(fname, [template_hash].to_yaml)
      end
    else
      raise "Argument is not a filename or directory"
    end
  end

private

  def import_customization_templates(customization_templates)
    begin
      customization_templates.each do |ct|
        customization_template = CustomizationTemplate.create(ct)
      end
    rescue
      raise ParsedNonDialogYamlError
    end
  end

  def export_customization_templates(customization_templates)
    # CustomizationTemplate objects have a relation with PxeImageType objects
    # through the pxe_image_type_id attribute.
    # As of CloudForms 3.1, PxeImageTypes are a fixed collection of objects
    # which cannot be modified in the application,
    # so we do not export them together with the Customization Templates.
    
    customization_templates.collect do |customization_template|
      included_attributes(customization_template.attributes, ["id", "created_at", "updated_at"])
    end.compact
  end

  def included_attributes(attributes, excluded_attributes)
    attributes.reject { |key, _| excluded_attributes.include?(key) }
  end

end

namespace :rhconsulting do
  namespace :customization_templates do

    desc 'Usage information'
    task :usage => [:environment] do
      puts 'Export - Usage: rake rhconsulting:customization_templates:export[/path/to/export]'
      puts 'Import - Usage: rake rhconsulting:customization_templates:import[/path/to/import]'
    end

    desc 'Import all customization templates from a YAML file or directory'
    task :import, [:filename] => [:environment] do |_, arguments|
      CustomizationTemplateImportExport.new.import(arguments[:filename])
    end

    desc 'Exports all customization templates to a YAML file or directory'
    task :export, [:filename] => [:environment] do |_, arguments|
      options = RhconsultingOptions.parse_options(arguments.extras)
      CustomizationTemplateImportExport.new.export(arguments[:filename], options)
    end

  end
end
