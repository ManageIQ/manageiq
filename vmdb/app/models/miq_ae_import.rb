class MiqAeImport
  def self.new(domain, options)
    if options['zip_file'].blank?
      MiqAeYamlImportFs.new(domain, options)
    else
      MiqAeYamlImportZipfs.new(domain, options)
    end
  end
end
