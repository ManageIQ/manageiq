# Class to Export Automate Model to a zip file
class MiqAeYamlExportZipfs < MiqAeYamlExport
  def initialize(domain, options)
    super
    @temp_file_name = File.join(Dir.tmpdir, "temp_file.zip")
    @zipfile_name   = options['zip_file'].blank? ? "#{@domain}.zip" : options['zip_file']
    options['overwrite'] ||= false
    if File.exist?(@zipfile_name) && !options['overwrite']
      raise MiqAeException::FileExists, "File [#{@zipfile_name}] exists, to overwrite it use OVERWRITE=true"
    end
  end

  def write_data(base_path, export_hash)
    @zip_file.dir.mkdir(base_path) unless @zip_file.file.directory?(base_path)
    fq_filename = File.join(base_path, export_hash['output_filename'].downcase)
    @zip_file.file.open(fq_filename, "w") { |zipf| zipf.puts export_hash['export_data'] }
    $log.info("#{self.class} writing zip fqfilename: #{fq_filename}")
  end

  def export
    require 'zip/zipfilesystem'

    Zip::ZipFile.open(@temp_file_name, Zip::ZipFile::CREATE) do |zf|
      @zip_file = zf
      write_model
      @zip_file.close unless @zip_file.nil?
      FileUtils.mv(@temp_file_name, @options['zip_file'])
    end
  ensure
    @zip_file = nil
  end
end
