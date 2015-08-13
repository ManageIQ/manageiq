# Class to Export Automate Model into a single YAML file
class MiqAeYamlExportConsolidated < MiqAeYamlExport
  include MiqAeYamlImportExportMixin

  def initialize(domain, options)
    super
    @temp_file_name = File.join(Dir.tmpdir, "temp_file.yaml")
    @yaml_file_name = options['yaml_file'].blank? ? "#{@domain}.yaml" : options['yaml_file']
    options['overwrite'] ||= false
    if File.exist?(@yaml_file_name) && !options['overwrite']
      raise MiqAeException::FileExists, "File [#{@yaml_file_name}] exists, to overwrite it use OVERWRITE=true"
    end
    @yaml_model = {}
  end

  def write_data(base_path, export_hash)
    path = File.join(base_path, export_hash['output_filename']).split('/')
    path.shift  if base_path[0, 1]  == '/'
    data = export_hash['export_data']
    data = YAML.load(data) if export_hash['output_filename'].ends_with?('.yaml')
    path << data
    @yaml_model.store_path(*path)
  end

  def export
    File.open(@temp_file_name, 'w') do |fd|
      write_model
      fd.write(@yaml_model.to_yaml)
      fd.close
      FileUtils.mv(@temp_file_name, @options['yaml_file'])
    end
  end
end
