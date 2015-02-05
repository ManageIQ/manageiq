class MiqAeImport
  def self.new(domain, options)
    if options['zip_file'].present?
      MiqAeYamlImportZipfs.new(domain, options)
    elsif options['import_dir'].present?
      MiqAeYamlImportFs.new(domain, options)
    elsif options['yaml_file'].present?
      MiqAeYamlImportConsolidated.new(domain, options)
    end
  end
end
