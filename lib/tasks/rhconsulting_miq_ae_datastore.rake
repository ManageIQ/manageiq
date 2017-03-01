# Author: George Goh <george.goh@redhat.com>

class MiqAeDatastoreImportExport
  class ParsedNonDialogYamlError < StandardError; end

  def import(domain_name, options)
    raise "Must supply domain name" if domain_name.blank?
    raise "Must supply import source directory" if options['import_dir'].blank?
    importer = MiqAeYamlImportFs.new(domain_name, options)
    # Overwrite doesn't work in ManageIQ/CloudForms < 4.1 (cfme version 5.6)
    # In these versions we have to manually delete the domain and then import.
    # This is exactly what happens in newer versions where overwrite is fixed.
    if options['overwrite'] && Vmdb::Appliance.VERSION < "5.6"
      domain_obj = MiqAeDomain.find_by_name(domain_name)
      domain_obj.destroy if domain_obj
    end
    importer.import
  end

  def export(domain_name, export_dir)
    raise "Must supply domain name" if domain_name.blank?
    raise "Must supply directory to export to" if export_dir.blank?
    exporter = MiqAeYamlExportFs.new(domain_name, {"export_dir" => export_dir, "overwrite" => true})
    exporter.export
  end
end

namespace :rhconsulting do
  namespace :miq_ae_datastore do

    desc 'Usage information'
    task :usage => [:environment] do
      puts 'Export - Usage: rake \'rhconsulting:miq_ae_datastore:export[domain_to_export,/path/to/export]\''
      puts 'Import - Usage: rake \'rhconsulting:miq_ae_datastore:import[domain_to_import,/path/to/import]\''
      puts "Import (Disabled) - Usage: rake 'rhconsulting:miq_ae_datastore:import_disabled[domain_to_import,/path/to/import]'"
      puts "Import with options - Usage: rake 'rhconsulting:miq_ae_datastore:import[domain_to_import,/path/to/import,option=value;option2=value2'"
      puts '  Where each option is one of:'
      puts '   * enabled=<true|false>'
      puts '   * import_as=<new_domain_name>'
      puts '   * overwrite=true'
      puts '   * tenant_name=<tenant_name>'
      puts '   * tenant_id=<tenant_id>'
    end

    desc 'Import a specific AE Datastore domain from a directory'
    task :import, [:domain_name, :filename] => [:environment] do |_, arguments|
      MiqAeDatastoreImportExport.new.import(arguments[:domain_name], 'import_dir' => arguments[:filename], 'enabled' => true)
    end

    desc 'Import a specific AE Datastore domain from a directory as disabled'
    task :import_disabled, [:domain_name, :filename] => [:environment] do |_, arguments|
      MiqAeDatastoreImportExport.new.import(arguments[:domain_name], 'import_dir' => arguments[:filename], 'enabled' => false)
    end

    desc 'Import a specific datastore with options.'
    task :import_with_options, [:domain_name, :filename, :options] => [:environment] do |_, arguments|
      options = { 'import_dir' => arguments[:filename] }

      # Add in any extra options passed in.
      arguments['options'].split(';').each do |passed_option|
        option, value = passed_option.split('=')
        case option
        when 'enabled'
          options['enabled'] = value =~ /^true$/ ? true : false
        when 'overwrite'
          # Only set overwrite when explicitly true. Some internal code treats
          # any value as true.
          options['overwrite'] = true if value =~ /^true$/
        when 'tenant_name'
          # Tenant find_by_name does not work for the root tenant. In some
          # places it is renamed as in the display, but in others like
          # find_by_name it stays 'My Company'
          tenant = Tenant.all.find { |t| t.name == tenant_name }
          raise "Tenant #{value} not found." unless tenant
          options['tenant_id'] = tenant.id
        when 'tenant_id', 'import_as'
          options[option] = value
        else
          raise ArgumentError, "Unrecognized option #{option}"
        end
      end
      MiqAeDatastoreImportExport.new.import(arguments[:domain_name], options)
    end

    desc 'Exports a specific AE Datastore domain to a directory'
    task :export, [:domain_name, :filename] => [:environment] do |_, arguments|
      MiqAeDatastoreImportExport.new.export(arguments[:domain_name], arguments[:filename])
    end

  end
end
