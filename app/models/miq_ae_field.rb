class MiqAeField < ApplicationRecord
  include MiqAeSetUserInfoMixin
  include MiqAeYamlImportExportMixin

  belongs_to :ae_class,   :class_name => "MiqAeClass",  :foreign_key => :class_id, :touch => true
  belongs_to :ae_method,  :class_name => "MiqAeMethod", :foreign_key => :method_id, :touch => true
  has_many   :ae_values,  :class_name => "MiqAeValue",  :foreign_key => :field_id, :dependent => :destroy,
                          :inverse_of => :ae_field

  validates :name, :uniqueness_when_changed => {:scope => [:class_id, :method_id], :case_sensitive => false},
                   :presence                => true,
                   :format                  => {:with => /\A[\w]+\z/i, :message => N_("may contain only alphanumeric and _ characters")}

  validates_inclusion_of  :substitute, :in => [true, false]

  NULL_COALESCING_DATATYPE = "null coalescing".freeze
  AVAILABLE_SCOPES    = ["class", "instance", "local"]
  validates_inclusion_of  :scope,      :in => AVAILABLE_SCOPES,    :allow_nil => true  # nil => instance
  AVAILABLE_AETYPES   = ["assertion", "attribute", "method", "relationship", "state"]
  validates_inclusion_of  :aetype,     :in => AVAILABLE_AETYPES,   :allow_nil => true  # nil => attribute
  AVAILABLE_DATATYPES_FOR_UI = ["string", "symbol", "integer", "float", "boolean", "time",
                                "array", "password", NULL_COALESCING_DATATYPE].freeze
  AVAILABLE_DATATYPES        = AVAILABLE_DATATYPES_FOR_UI +
                               %w(host
                                  vm
                                  storage
                                  ems
                                  policy
                                  server
                                  request
                                  provision
                                  user)
  validates_inclusion_of  :datatype,   :in => AVAILABLE_DATATYPES, :allow_nil => true  # nil => string

  before_save        :set_message_and_default_value

  DEFAULTS = {:substitute => true, :datatype => "string", :aetype => "attribute", :scope => "instance", :message => "create"}

  def self.available_aetypes
    AVAILABLE_AETYPES
  end

  def self.available_datatypes
    AVAILABLE_DATATYPES
  end

  class <<self
    alias available_datatypes_for_ui available_datatypes
  end

  def self.defaults
    DEFAULTS
  end

  def self.default(key)
    DEFAULTS[key.to_sym]
  end

  def self.lookup_by_name(name)
    where("lower(name) = ?", name.downcase).first
  end

  singleton_class.send(:alias_method, :find_by_name, :lookup_by_name)
  Vmdb::Deprecation.deprecate_methods(singleton_class, :find_by_name => :lookup_by_name)

  def default_value=(value)
    set_default_value(value)
  end

  def to_export_yaml
    {"field" => export_attributes}
  end

  def to_export_xml(options = {})
    require 'builder'
    xml = options[:builder] ||= ::Builder::XmlMarkup.new(:indent => options[:indent])

    xml_attrs = {:name => name, :substitute => substitute.to_s}

    self.class.column_names.each do |cname|
      # Remove any columns that we do not want to export
      next if %w(id created_on updated_on updated_by).include?(cname) || cname.ends_with?("_id")

      # Skip any columns that we process explicitly
      next if %w(name default_value substitute).include?(cname)

      # Process the column
      xml_attrs[cname.to_sym]  = send(cname)   unless send(cname).blank?
    end

    xml.MiqAeField(xml_attrs) do
      xml.text!(default_value)   unless default_value.blank?
    end
  end

  def substitute=(value)
    value = false if value.nil?
    super
  end

  def set_message_and_default_value
    self.message ||= DEFAULTS[:message]
    set_default_value(default_value)
  end

  delegate :editable?, :to => :ae_class

  def self.display_name(number = 1)
    n_('Automation Field', 'Automation Fields', number)
  end

  private

  def set_default_value(value)
    write_attribute(:default_value, (datatype == "password") ? MiqAePassword.encrypt(value) : value)
  end
end
