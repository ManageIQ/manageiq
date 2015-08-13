# YAML Export Class of an Automate Model, based on the options passed in
# calls either the ZIP or the Fileystem class
class MiqAeExport
  def self.new(domain, options)
    if options['zip_file'].present?
      @inst = MiqAeYamlExportZipfs.new(domain, options)
    elsif options['export_dir'].present?
      @inst = MiqAeYamlExportFs.new(domain, options)
    elsif options['yaml_file'].present?
      @inst = MiqAeYamlExportConsolidated.new(domain, options)
    end
  end
end
