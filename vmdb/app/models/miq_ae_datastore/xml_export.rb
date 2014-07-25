require "builder"

module MiqAeDatastore
  class XmlExport
    def self.to_xml
      $log.info("MIQ(MiqAeDatastore) Exporting to XML") if $log
      xml = Builder::XmlMarkup.new(:indent => 2)
      xml.instruct!
      xml.MiqAeDatastore(:version => '1.0') do
        MiqAeClass.all.sort_by(&:fqname).each do |miq_ae_class|
          miq_ae_class.to_export_xml(:builder => xml, :skip_instruct => true, :indent => 2)
        end
        CustomButton.all.each do |custom_button|
          custom_button.to_export_xml(:builder => xml, :skip_instruct => true, :indent => 2)
        end
      end
    end

    def self.class_to_xml(ns, class_name)
      $log.info("MIQ(MiqAeDatastore) Exporting class: #{class_name} to XML") if $log
      xml = Builder::XmlMarkup.new(:indent => 2)
      xml.instruct!
      xml.MiqAeDatastore(:version => '1.0') do
        c = MiqAeClass.find_by_namespace_and_name(ns, class_name)
        c.to_export_xml(:builder => xml, :skip_instruct => true, :indent => 2)
      end
    end

    def self.export_sub_namespaces(ns, xml)
      ns.ae_namespaces.each do |n|
        sn = MiqAeNamespace.find_by_fqname(n.fqname)
        export_all_classes_for_namespace(sn, xml)
        export_sub_namespaces(sn, xml)
      end
    end

    def self.namespace_to_xml(namespace)
      $log.info("MIQ(MiqAeDatastore) Exporting namespace: #{namespace} to XML") if $log
      xml = Builder::XmlMarkup.new(:indent => 2)
      xml.instruct!
      rec = MiqAeNamespace.find_by_fqname(namespace)
      if rec.nil?
        $log.info("MIQ(MiqAeDatastore) Namespace:  <#{namespace}> not found.") if $log
        return nil
      end

      xml.MiqAeDatastore(:version => '1.0') do
        export_all_classes_for_namespace(rec, xml)
        export_sub_namespaces(rec, xml)
      end
    end

    def self.export_all_classes_for_namespace(ns, xml)
      MiqAeClass.find_all_by_namespace_id(ns.id.to_i).sort_by(&:fqname).each  do  |c|
        c.to_export_xml(:builder => xml, :skip_instruct => true, :indent => 2)
      end
    end
  end
end
