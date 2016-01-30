module MiqAeDatastore
  class XmlYamlConverter
    def self.convert(xml, domain_name, export_options)
      temp_domain = MiqAeDatastore.temp_domain.downcase
      MiqAeDomain.create!(:name   => temp_domain, :priority => 100, :enabled => false,
                          :tenant => Tenant.root_tenant)
      MiqAeDatastore::XmlImport.load_xml(xml, temp_domain)
      export_options['export_as'] = domain_name
      MiqAeExport.new(temp_domain, export_options).export
    ensure
      ns = MiqAeDomain.find_by_fqname(temp_domain)
      ns.destroy if ns
    end
  end
end
