require 'miq-syntax-checker'

class MiqAeMethod < ActiveRecord::Base
  include MiqAeSetUserInfoMixin
  include MiqAeYamlImportExportMixin

  belongs_to :ae_class,     :class_name => "MiqAeClass", :foreign_key => :class_id
  has_many   :inputs,       :class_name => "MiqAeField", :foreign_key => :method_id, :dependent => :destroy, :order => :priority

  validates_presence_of   :name, :scope
  validates_uniqueness_of :name, :case_sensitive => false, :scope => [:class_id, :scope]
  validates_format_of     :name, :with => /\A[A-Za-z0-9_]+\z/i

  AVAILABLE_LANGUAGES  = [ "ruby", "perl" ]  # someday, add sh, perl, python, tcl and any other scripting language
  validates_inclusion_of  :language,  :in => AVAILABLE_LANGUAGES
  AVAILABLE_LOCATIONS  = [ "builtin", "inline", "uri" ]
  validates_inclusion_of  :location,  :in => AVAILABLE_LOCATIONS
  AVAILABLE_SCOPES     = [ "class", "instance" ]
  validates_inclusion_of  :scope,     :in => AVAILABLE_SCOPES

  include ReportableMixin

  def self.available_languages
    AVAILABLE_LANGUAGES
  end

  def self.available_locations
    AVAILABLE_LOCATIONS
  end

  def self.available_scopes
    AVAILABLE_SCOPES
  end

  # Validate the syntax of the passed in inline ruby code
  def self.validate_syntax(code_text)
    result = MiqSyntaxChecker.check(code_text)
    return nil if result.valid?
    return [[result.error_line, result.error_text]] # Array of arrays for future multi-line support
  end

  def fqname
    "#{self.ae_class.fqname}/#{self.name}"
  end

  def self.default_method_text
    <<-DEFAULT_METHOD_TEXT
#
# Description: <Method description here>
#
    DEFAULT_METHOD_TEXT
  end

  def to_export_yaml
    export_attributes
  end

  def method_inputs
    inputs.collect(&:to_export_yaml)
  end

  def to_export_xml(options = {})
    require 'builder'
    xml = options[:builder] ||= ::Builder::XmlMarkup.new(:indent => options[:indent])
    xml_attrs = { :name => self.name, :language => self.language, :scope => self.scope, :location => self.location }

    self.class.column_names.each { |cname|
      # Remove any columns that we do not want to export
      next if %w(id created_on updated_on updated_by).include?(cname) || cname.ends_with?("_id")

      # Skip any columns that we process explicitly
      next if %w(name language scope location data).include?(cname)

      # Process the column
      xml_attrs[cname.to_sym]  = self.send(cname)   unless self.send(cname).blank?
    }

    xml.MiqAeMethod(xml_attrs) {
      xml.target!.chomp!
      xml << "<![CDATA[#{self.data}]]>"
      self.inputs.each { |i| i.to_export_xml(:builder => xml) }
    }
  end

  def editable?
    ae_class.ae_namespace.editable?
  end

  def field_names
    inputs.collect { |f| f.name.downcase }
  end

  def field_value_hash(name)
    field = inputs.detect { |f| f.name.casecmp(name) == 0 }
    raise "Field #{name} not found in method #{self.name}" if field.nil?
    field.attributes
  end

  def self.copy(ids, domain, namespace, overwrite_location)
    MiqAeMethodCopy.copy_multiple(ids, domain, namespace, overwrite_location)
  end
end
