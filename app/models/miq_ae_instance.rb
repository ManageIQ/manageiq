class MiqAeInstance < ApplicationRecord
  include MiqAeSetUserInfoMixin
  include MiqAeYamlImportExportMixin

  belongs_to :ae_class,  -> { includes(:ae_fields) }, :class_name => "MiqAeClass", :foreign_key => :class_id
  has_many   :ae_values, -> { includes(:ae_field) }, :class_name => "MiqAeValue", :foreign_key => :instance_id,
                         :dependent => :destroy, :autosave => true

  validates_uniqueness_of :name, :case_sensitive => false, :scope => :class_id
  validates_presence_of   :name
  validates_format_of     :name, :with    => /\A[\w.-]+\z/i,
                                 :message => N_("may contain only alphanumeric and _ . - characters")

  def self.find_by_name(name)
    where("lower(name) = ?", name.downcase).first
  end

  def get_field_attribute(field, validate, attribute)
    if validate
      field, fname = validate_field(field)
      raise MiqAeException::FieldNotFound, "Field [#{fname}] not found in MiqAeDatastore" if field.nil?
    end

    val = ae_values.detect { |v| v.field_id == field.id }
    val.respond_to?(attribute) ? val.send(attribute) : nil
  end

  def set_field_attribute(field, value, attribute)
    field, fname = validate_field(field)
    raise MiqAeException::FieldNotFound, "Field [#{fname}] not found in MiqAeDatastore" if field.nil?

    val   = ae_values.detect { |v| v.field_id == field.id }
    val ||= ae_values.build(:field_id => field.id)
    val.send("#{attribute}=", value)
    val.save!
  end

  def get_field_collect(field, validate = true)
    get_field_attribute(field, validate, :collect)
  end

  def set_field_collect(field, value)
    set_field_attribute(field, value, :collect)
  end

  def get_field_value(field, validate = true)
    get_field_attribute(field, validate, :value)
  end

  def set_field_value(field, value)
    set_field_attribute(field, value, :value)
  end

  def field_attributes
    result = {}
    ae_class.ae_fields.each do |f|
      result[f.name] = get_field_value(f, false)
    end
    result
  end

  def fqname
    "#{ae_class.fqname}/#{name}"
  end

  delegate :domain, :to => :ae_class

  def export_ae_fields
    ae_values_sorted.collect(&:to_export_yaml).compact
  end

  # TODO: Limit search to within the context of a class id?
  def self.search(str)
    str[-1, 1] = "%" if str[-1, 1] == "*"
    where("lower(name) LIKE ?", str.downcase).pluck(:name)
  end

  def to_export_xml(options = {})
    require 'builder'
    xml = options[:builder] ||= ::Builder::XmlMarkup.new(:indent => options[:indent])
    xml_attrs = {:name => name}

    self.class.column_names.each do |cname|
      # Remove any columns that we do not want to export
      next if %w(id created_on updated_on updated_by).include?(cname) || cname.ends_with?("_id")

      # Skip any columns that we process explicitly
      next if %w(name).include?(cname)

      # Process the column
      xml_attrs[cname.to_sym]  = send(cname)   unless send(cname).blank?
    end

    xml.MiqAeInstance(xml_attrs) do
      ae_values_sorted.each { |v| v.to_export_xml(:builder => xml) }
    end
  end

  def ae_values_sorted
    ae_class.ae_fields.sort_by(&:priority).collect do |field|
      ae_values.detect { |value| value.field_id == field.id }
    end.compact
  end

  delegate :editable?, :to => :ae_class

  def field_names
    fields = ae_values.collect(&:field_id)
    ae_class.ae_fields.select { |x| fields.include?(x.id) }.collect { |f| f.name.downcase }
  end

  def field_value_hash(name)
    field = ae_class.ae_fields.detect { |f| f.name.casecmp(name) == 0 }
    raise "Field #{name} not found in class #{ae_class.fqname}" if field.nil?
    value = ae_values.detect { |v| v.field_id == field.id }
    raise "Field #{name} not found in instance #{self.name} in class #{ae_class.fqname}" if value.nil?
    value.attributes
  end

  def self.copy(options)
    if options[:new_name]
      MiqAeInstanceCopy.new(options[:fqname]).as(options[:new_name],
                                                 options[:namespace],
                                                 options[:overwrite_location]
                                                )
    else
      MiqAeInstanceCopy.copy_multiple(options[:ids],
                                      options[:domain],
                                      options[:namespace],
                                      options[:overwrite_location]
                                     )
    end
  end

  def self.get_homonymic_across_domains(user, fqname, enabled = nil)
    MiqAeDatastore.get_homonymic_across_domains(user, ::MiqAeInstance, fqname, enabled)
  end

  private

  def validate_field(field)
    if field.kind_of?(MiqAeField)
      fname = field.name
      field = nil unless ae_class.ae_fields.include?(field)
    else
      fname = field
      field = ae_class.ae_fields.detect { |f| fname.casecmp(f.name) == 0 }
    end
    return field, fname
  end
end
