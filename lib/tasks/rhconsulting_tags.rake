require_relative 'rhconsulting_illegal_chars'
require_relative 'rhconsulting_options'

class TagImportExport
  class ParsedNonClassificationYamlError < StandardError; end

  SPECIAL_TAGS = ['folder_path_blue', 'folder_path_yellow', 'role']

  def import(filename)
    raise "Must supply filename or directory" if filename.blank?
    if File.file?(filename)
      import_file(filename)
    elsif File.directory?(filename)
      Dir.glob("#{filename}/*.yaml") do |fname|
        import_file(fname)
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

    if file_type == 'file'
      File.write(filename, Classification.export_to_yaml)
    elsif file_type == 'directory'
      Classification.where(:parent_id => "0").each do |category|
        # Skip exporting classifications where
        #   the classification does not show in the Web UI
        next if SPECIAL_TAGS.include?(category.name)

        # Get the description to use in the filename
        description = "#{category.description}"

        # Replace invalid filename characters
        description = MiqIllegalChars.replace(description, options)
        fname = "#{filename}/#{description}.yaml"

        File.write(fname, category.export_to_yaml)
      end
    end
  end

private

  UPDATE_FIELDS = ['description', 'example_text', 'show', 'perf_by_tag']

  def import_file(filename)
    classifications = YAML.load_file(filename)
    Classification.transaction do
      import_classifications(classifications)
    end
  end

  def import_entries(classification, entries)
    entries.each do |e|
      #puts "Tag: [#{e['name']}]"
      entry = classification.find_entry_by_name(e['name'])
      if entry
        entry.update_attributes!(e.select { |k| UPDATE_FIELDS.include?(k) })
      else
        Classification.create(e.merge('parent_id' => classification.id))
      end
    end
  end

  def import_classifications(classifications)
    begin
      classifications.each do |c|
        next if SPECIAL_TAGS.include?(c['name'])
        #puts "Classification: [#{c['name']}]"
        classification = Classification.find_by_name(c['name'])
        entries = c.delete("entries")
        if classification
          classification.update_attributes!(c.select { |k| UPDATE_FIELDS.include?(k) })
        else
          classification = Classification.create(c)
        end
        import_entries(classification, entries)
      end
    rescue
      raise ParsedNonClassificationYamlError
    end
  end
end

namespace :rhconsulting do
  namespace :tags do

    desc 'Usage information'
    task :usage => [:environment] do
      puts 'Export - Usage: rake rhconsulting:tags:export[/path/to/export]'
      puts 'Import - Usage: rake rhconsulting:tags:import[/path/to/import]'
    end

    desc 'Import all tags from a YAML file'
    task :import, [:filename] => [:environment] do |_, arguments|
      TagImportExport.new.import(arguments[:filename])
    end

    desc 'Exports all tags to a YAML file'
    task :export, [:filename] => [:environment] do |_, arguments|
      options = RhconsultingOptions.parse_options(arguments.extras)
      TagImportExport.new.export(arguments[:filename], options)
    end

  end
end
