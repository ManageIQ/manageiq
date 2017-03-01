# Author: Brant Evans <bevans@redhat.com>
require_relative 'rhconsulting_illegal_chars'
require_relative 'rhconsulting_options'

class MiqWidgetsImportExport
  class ParsedNonDialogYamlError < StandardError; end

  def export(export_dir, options = {})
    raise "Must supply export dir" if export_dir.blank?

    # Export the Policies
    export_widgets(export_dir, options)
  end

  def import(import_dir)
    raise "Must supply import dir" if import_dir.blank?

    # Import the Policy Profiles
    import_widgets(import_dir)
  end

private

  def export_widgets(export_dir, options)
    custom_widgets = MiqWidget.where(:read_only => "false")
    custom_widgets.each { |widget|

      # Set the filename and replace spaces and characters that are not allowed in filenames
      fname = MiqIllegalChars.replace("#{widget.id}_#{widget.name}.yaml", options)

      File.write("#{export_dir}/#{fname}", widget.export_to_array.to_yaml)
    }
  end

  def import_widgets(import_dir)
    MiqWidget.transaction do
      Dir.glob("#{import_dir}/*yaml") do |filename|
        widgets = YAML.load_file(filename)
        widgets.each do |widget|
          MiqWidget.import_from_hash(widget['MiqWidget'], {:userid=>'admin', :overwrite=>true, :save=>true})
        end
      end
    end
  end

end

namespace :rhconsulting do
  namespace :miq_widgets do

    desc 'Usage information'
    task :usage => [:environment] do
      puts 'Export - Usage: rake \'rhconsulting:miq_widgets:export[/path/to/dir/with/widgets]\''
      puts 'Import - Usage: rake \'rhconsulting:miq_widgets:import[/path/to/dir/with/widgets]\''
    end

    desc 'Exports all widgets to individual YAML files'
    task :export, [:filedir] => [:environment] do |_, arguments|
      options = RhconsultingOptions.parse_options(arguments.extras)
      MiqWidgetsImportExport.new.export(arguments[:filedir], options)
    end

    desc 'Imports all policies from individual YAML files'
    task :import, [:filedir] => [:environment] do |_, arguments|
      MiqWidgetsImportExport.new.import(arguments[:filedir])
    end

  end
end
