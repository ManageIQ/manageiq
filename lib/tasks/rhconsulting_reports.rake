# Author: George Goh <george.goh@redhat.com>
require_relative 'rhconsulting_illegal_chars'
require_relative 'rhconsulting_options'

class MiqReportImportExport
  class ParsedNonDialogYamlError < StandardError; end

  def import(import_dir)
    raise "Must supply import dir" if import_dir.blank?
    MiqReport.transaction do
      Dir.foreach(import_dir) do |filename|
      	next if filename == '.' or filename == '..'
      	reports = YAML.load_file("#{import_dir}/#{filename}")
        reports.each { |report|
          MiqReport.import_from_hash(report, {:userid=>'admin',
                                              :overwrite=>true,
                                              :save=>true})
        }
      end
    end
  end

  def export(export_dir, options = {})
    raise "Must supply export dir" if export_dir.blank?
    custom_reports = MiqReport.where(:rpt_type => "Custom")
    custom_reports.each { |report|
      # Replace invalid filename characters
      name = MiqIllegalChars.replace(report.name, options)
      fname = "#{report.id}_#{name}.yaml"
      File.write("#{export_dir}/#{fname}", report.export_to_array.to_yaml)
    }
  end
end

namespace :rhconsulting do
  namespace :miq_reports do

    desc 'Usage information'
    task :usage => [:environment] do
      puts 'Export - Usage: rake \'rhconsulting:miq_reports:export[/path/to/dir/with/reports]\''
      puts 'Import - Usage: rake \'rhconsulting:miq_reports:import[/path/to/dir/with/reports]\''
    end

    desc 'Import all reports from individual YAML files'
    task :import, [:filedir] => [:environment] do |_, arguments|
      MiqReportImportExport.new.import(arguments[:filedir])
    end

    desc 'Exports all custom reports to individual YAML files'
    task :export, [:filedir] => [:environment] do |_, arguments|
      options = RhconsultingOptions.parse_options(arguments.extras)
      MiqReportImportExport.new.export(arguments[:filedir], options)
    end

  end
end
