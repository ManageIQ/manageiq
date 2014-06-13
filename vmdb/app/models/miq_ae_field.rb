class MiqAeField < ActiveRecord::Base
  include MiqAeSetUserInfoMixin
  include MiqAeYamlImportExportMixin

  belongs_to :ae_class,   :class_name => "MiqAeClass",  :foreign_key => :class_id
  belongs_to :ae_method,  :class_name => "MiqAeMethod", :foreign_key => :method_id
  has_many   :ae_values,  :class_name => "MiqAeValue",  :foreign_key => :field_id, :dependent => :destroy

  validates_uniqueness_of :name, :case_sensitive => false, :scope => [:class_id, :method_id]
  validates_presence_of   :name
  validates_format_of     :name, :with => /\A[A-Za-z0-9_]+\z/i

  validates_inclusion_of  :substitute, :in => [true, false]
  AVAILABLE_SCOPES    = [ "class", "instance", "local" ]
  validates_inclusion_of  :scope,      :in => AVAILABLE_SCOPES,    :allow_nil => true  # nil => instance
  AVAILABLE_AETYPES   = [ "assertion", "attribute", "method", "relationship", "state" ]
  validates_inclusion_of  :aetype,     :in => AVAILABLE_AETYPES,   :allow_nil => true  # nil => attribute
  AVAILABLE_DATATYPES_FOR_UI = [ "string", "symbol", "integer", "float", "boolean", "time", "array", "password"]
  AVAILABLE_DATATYPES        = AVAILABLE_DATATYPES_FOR_UI + [ "host", "vm", "storage", "ems", "policy", "server", "request", "provision" ]
  validates_inclusion_of  :datatype,   :in => AVAILABLE_DATATYPES, :allow_nil => true  # nil => string

  include ReportableMixin

  before_save        :set_message_and_default_value

  DEFAULTS = {:substitute => true, :datatype => "string", :aetype => "attribute", :scope => "instance", :message => "create" }

  def self.available_aetypes
    AVAILABLE_AETYPES
  end

  def self.available_datatypes_for_ui
    AVAILABLE_DATATYPES_FOR_UI
  end

  def self.available_datatypes
    AVAILABLE_DATATYPES
  end

  def self.defaults
    DEFAULTS
  end

  def self.default(key)
    DEFAULTS[key.to_sym]
  end

  def self.find_by_name(name)
    self.find(:first, :conditions => ["lower(name) = ?", name.downcase])
  end

  def default_value=(value)
    set_default_value(value)
  end

  def to_export_yaml
    {"field" => export_attributes}
  end

  def to_export_xml(options = {})
    require 'builder'
    xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])

    xml_attrs = { :name => self.name, :substitute => self.substitute.to_s }

    self.class.column_names.each { |cname|
      # Remove any columns that we do not want to export
      next if ["id", "created_on", "updated_on", "updated_by", "reserved"].include?(cname) || cname.ends_with?("_id")

      # Skip any columns that we process explicitly
      next if ["name", "default_value", "substitute"].include?(cname)

      # Process the column
      xml_attrs[cname.to_sym]  = self.send(cname)   unless self.send(cname).blank?
    }

    xml.MiqAeField(xml_attrs) {
      xml.text!(self.default_value)   unless self.default_value.blank?
    }
  end

  def substitute=(value)
    # Any invalid boolean string should be converted to default
    column_class = self.class.columns_hash['substitute'].class
    unless column_class::TRUE_VALUES.include?(value) ||
           column_class::FALSE_VALUES.include?(value)
      value = DEFAULTS[:substitute]
    end
    super
  end

  def set_message_and_default_value
    self.message ||= DEFAULTS[:message]
    set_default_value(self.default_value)
  end

  def editable?
    ae_class.ae_namespace.editable?
  end

  private

  def set_default_value(value)
    write_attribute(:default_value, (self.datatype == "password") ? MiqAePassword.encrypt(value) : value)
  end
end
