require_relative 'rhconsulting_illegal_chars'
require_relative 'rhconsulting_options'

class RoleImportExport
  class ParsedNonDialogYamlError < StandardError; end

  def import(filename)
    raise "Must supply filename or directory" if filename.blank?
    if File.file?(filename)
      roles = YAML.load_file(filename)
      import_roles(roles)
    elsif File.directory?(filename)
      Dir.glob("#{filename}/*.yaml") do |fname|
        roles = YAML.load_file(fname)
        import_roles(roles)
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

    roles_array = export_roles(MiqUserRole.order(:id).all)

    if file_type == 'file'
      File.write(filename, roles_array.to_yaml)
    elsif file_type == 'directory'
      roles_array.each do |role_hash|
        role_name = role_hash["name"]
        # Replace invalid filename characters
        role_name = MiqIllegalChars.replace(role_name, options)
        fname = "#{filename}/#{role_name}.yaml"
        File.write(fname, [role_hash].to_yaml)
      end
    else
      raise "Argument is not a filename or directory"
    end
  end

private

  def import_roles(roles)
    begin
      roles.each do |r|
        r['miq_product_feature_ids'] = MiqProductFeature.all.collect do |f|
          f.id if r['feature_identifiers'] && r['feature_identifiers'].include?(f.identifier)
        end.compact
        role = MiqUserRole.find_or_create_by(name: r['name'])
        role.update_attributes!(r.reject { |k| k == 'feature_identifiers' })
      end
    rescue
      raise ParsedNonDialogYamlError
    end
  end

  def export_roles(roles)
    roles.collect do |role|
      next if role.read_only?
      included_attributes(role.attributes, ["created_at", "id", "updated_at"]).merge('feature_identifiers' => role.feature_identifiers)
    end.compact
  end

  def included_attributes(attributes, excluded_attributes)
    attributes.reject { |key, _| excluded_attributes.include?(key) }
  end

end

namespace :rhconsulting do
  namespace :roles do

    desc 'Usage information'
    task :usage => [:environment] do
      puts 'Export - Usage: rake rhconsulting:roles:export[/path/to/export]'
      puts 'Import - Usage: rake rhconsulting:roles:import[/path/to/export]'
    end

    desc 'Import all roles from a YAML file or directory'
    task :import, [:filename] => [:environment] do |_, arguments|
      RoleImportExport.new.import(arguments[:filename])
    end

    desc 'Exports all roles to a YAML file or directory'
    task :export, [:filename] => [:environment] do |_, arguments|
      options = RhconsultingOptions.parse_options(arguments.extras)
      RoleImportExport.new.export(arguments[:filename], options)
    end

  end
end
