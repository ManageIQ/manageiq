# Heavily based on a rails script written by Dustin Scott <dscott@redhat.com>
# Author: Brant Evans <bevans@redhat.com>
require_relative 'rhconsulting_illegal_chars'
require_relative 'rhconsulting_options'

class ProvisionDialogImportExport
  class ParsedNonDialogYamlError < StandardError; end

  def export(filedir, options = {})
    # Do some basic checks
    raise "Must supply export directory" if filedir.blank?
    raise "#{filedir} does not exist" if ! File.exist?(filedir)
    raise "#{filedir} is not a directory" if ! File.directory?(filedir)
    raise "#{filedir} is not a writable" if ! File.writable?(filedir)

    # Get the provision dialogs to export
    dialog_array = export_prov_dialogs

    # Save provision dialogs
    dialog_array.each do |dialog|
      # Set the filename and replace characters that are not allowed in filenames
      fname = MiqIllegalChars.replace("#{dialog[:name]}.yaml", options)
      File.write("#{filedir}/#{fname}", dialog.to_yaml)
    end
  end

  def import(import_name)
    raise "Must supply filename or directory" if import_name.blank?
    if File.file?(import_name)
      dialog = YAML.load_file(import_name)
      import_prov_dialogs(dialog)
    elsif File.directory?(import_name)
      Dir.glob("#{import_name}/*.yaml") do |fname|
        dialog = YAML.load_file(fname)
        import_prov_dialogs(dialog)
      end
    else
      raise "Argument is not a filename or directory"
    end
  end

  private

  def export_prov_dialogs
    dialog_array = []
    # Only export non-default dialogs
    MiqDialog.order(:id).where(:default => false).each do |dialog|
      dialog_hash = dialog.to_model_hash
      # Delete keys that are not needed. These will be recreated on import
      [ :class, :id, :created_at, :updated_at ].each { |key| dialog_hash.delete(key) }
      # Put the resulting hash in our array to return
      dialog_array << dialog_hash
    end
    # Return the array
    dialog_array
  end

  def import_prov_dialogs(dialog)
    # Check if there is already a dialog with the same name that is being imported
    model_dialog = MiqDialog.where(:name => dialog[:name]).first

    # If an existing dialog was found update it otherwise create a new dialog
    if model_dialog.nil? then
      MiqDialog.create(dialog)
    else
      model_dialog.update(dialog)
    end
  end
end

namespace :rhconsulting do
  namespace :provision_dialogs do

    desc 'Usage information'
    task :usage => [:environment] do
      puts 'Export - Usage: rake rhconsulting:provision_dialogs:export[/path/to/dir/with/dialogs]'
      puts 'Import - Usage: rake rhconsulting:provision_dialogs:import[/path/to/dir/with/dialogs]'
    end

    desc 'Import all provisioning dialogs to individual YAML files'
    task :import, [:filedir] => [:environment] do |_, arguments|
      ProvisionDialogImportExport.new.import(arguments[:filedir])
    end

    desc 'Exports all provisioning dialogs to individual YAML files'
    task :export, [:filedir] => [:environment] do |_, arguments|
      options = RhconsultingOptions.parse_options(arguments.extras)
      ProvisionDialogImportExport.new.export(arguments[:filedir], options)
    end

  end
end
