class MiqAeImport
  def self.new(domain, options)
    if options['zip_file'].present?
      MiqAeYamlImportZipfs.new(domain, options)
    elsif options['import_dir'].present?
      MiqAeYamlImportFs.new(domain, options)
    elsif options['yaml_file'].present?
      MiqAeYamlImportConsolidated.new(domain, options)
    elsif options['git_dir'].present?
      MiqAeYamlImportGitfs.new(domain, options)
    elsif options['git_url'].present? || options['git_repository_id'].present?
      MiqAeGitImport.new(options)
    end
  end
end
