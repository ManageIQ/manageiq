class MiqAeValue < ActiveRecord::Base
  include MiqAeSetUserInfoMixin
  include MiqAeYamlImportExportMixin
  belongs_to :ae_field,    :class_name => "MiqAeField",    :foreign_key => :field_id
  belongs_to :ae_instance, :class_name => "MiqAeInstance", :foreign_key => :instance_id

  include ReportableMixin

  def to_export_xml(options = {})
    require 'builder'
    xml = options[:builder] ||= ::Builder::XmlMarkup.new(:indent => options[:indent])
    xml_attrs = { :name => self.ae_field.name }

    self.class.column_names.each { |cname|
      # Remove any columns that we do not want to export
      next if %w(id created_on updated_on updated_by).include?(cname) || cname.ends_with?("_id")

      # Skip any columns that we process explicitly
      next if %w(name value).include?(cname)

      # Process the column
      xml_attrs[cname.to_sym]  = self.send(cname)   unless self.send(cname).blank?
    }

    xml.MiqAeField(xml_attrs) {
      self.value.blank? ? xml.cdata!(self.value.to_s) : xml.text!(self.value)
    }
  end

  def to_export_yaml
    hash = export_non_blank_attributes
    hash.empty? ? nil : {ae_field.name => hash}
  end

  def value=(value)
    write_attribute(:value, (ae_field.datatype == "password") ? MiqAePassword.encrypt(value) : value)
  end

end
