# Class to Export Automate Model to a directory on the file system
class MiqAeYamlExportFs < MiqAeYamlExport
  def initialize(domain, options)
    raise ArgumentError, "Output directory not specified" if options['export_dir'].blank?
    options['overwrite'] ||= false
    dom_name = options['export_as'].present? ? options['export_as'] : domain
    dir_name = File.join(options['export_dir'], dom_name)
    if Dir.exist?(dir_name) && !options['overwrite']
      raise MiqAeException::DirectoryExists, "Directory [#{dir_name}] exists, use OVERWRITE=true"
    end
    super
  end

  def write_data(base_path, export_hash)
    fqpath = File.join(@options['export_dir'], base_path)
    FileUtils.mkpath(fqpath) unless File.directory?(fqpath)
    fq_filename = File.join(fqpath, export_hash['output_filename'].downcase)
    raise MiqAeException::FileExists, "#{fq_filename} exists" if File.exist?(fq_filename) && !@options['overwrite']
    File.write(fq_filename, export_hash['export_data'])
  end

  def export
    write_model
  end
end
