# YAML Export Class of an Automate Model, based on the options passed in
# calls either the ZIP or the Fileystem class
class MiqAeExport
  def self.new(domain, options)
    if options['zip_file'].blank?
      @inst = MiqAeYamlExportFs.new(domain, options)
    else
      @inst = MiqAeYamlExportZipfs.new(domain, options)
    end
  end
end
