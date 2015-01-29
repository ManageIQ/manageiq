class MiqAeValue < MiqAeBase
  include MiqAeModelBase
  include MiqAeFsStore
  expose_columns :field_id, :instance_id, :value, :condition, :ae_field
  expose_columns :on_entry, :on_exit, :on_error, :max_retries, :max_time, :collect, :message
  expose_columns :description, :display_name, :name
  expose_columns :id, :created_on, :created_by_user_id
  expose_columns :updated_on, :updated_by, :updated_by_user_id

  validates_presence_of :field_id
  validates_presence_of :instance_id

  VALUE_ATTRIBUTES = %w(field_id instance_id value condition collect)

  def self.column_names
    %w(field_id instance_id value condition on_entry on_exit
       on_error max_retries max_time collect message
       description display_name name id created_on created_by_user_id
       updated_on updated_by updated_by_user_id)
  end

  def initialize(options = {})
    @attributes = HashWithIndifferentAccess.new(options)
    self.ae_field = @attributes.delete(:ae_field) if @attributes.key?(:ae_field)
    self.ae_instance = @attributes.delete(:ae_instance) if @attributes.key?(:ae_instance)
  end

  def self.base_class
    MiqAeValue
  end

  def self.base_model
    MiqAeValue
  end

  def self.count
    MiqAeDomain.fetch_count(MiqAeValue)
  end

  def build(options = {})
    new_with_hash(options)
  end

  def ae_instance
    @ae_instance ||= MiqAeInstance.find(instance_id)
  end

  def ae_instance=(obj)
    @ae_instance = obj
    @attributes[:instance_id] = obj.id
  end

  def ae_field
    @ae_field ||= MiqAeField.find(field_id)
  end

  def ae_field=(field)
    @ae_field = field
    @attributes[:field_id] = field.id
  end

  def generate_id
    self.id = "#{instance_id}##{ae_field.name}"
  end

  def auto_save
    self.name = ae_field.name
    self.field_id = ae_field.id
    context = persisted? ? :update : :create
    generate_id   unless id
    valid?(context).tap { |result| changes_applied if result }
  end

  def save
    # raise "save called directly for MiqAeValue"
    self.name = ae_field.name
    context = persisted? ? :update : :create
    generate_id   unless id
    return false unless valid?(context)
    apply_changes(context)
    @ae_instance.save
    changes_applied
    true
  end

  def export_attributes
    attributes.except(*(EXPORT_EXCLUDE_KEYS + ['name']))
  end

  def apply_changes(context)
    inst_value = ae_instance.ae_values.detect { |f| f.id == id }
    if context == :create
      ae_instance.ae_values << self unless inst_value
    elsif context == :update && object_id != inst_value.object_id
      attributes.each { |k, v| inst_value[k] = v } if inst_value
    end
  end

  def destroy
    @ae_instance.ae_values.delete_if { |v| v.id == id }
    @ae_instance.save
  end

  def to_export_yaml
    hash = export_non_blank_attributes
    hash.empty? ? nil : {ae_field.name => hash}
  end

  def value=(value)
    return if @attributes['value'] == value
    my_field = ae_field
    raise "Ae field not found for #{attributes[:field_id]}" unless my_field
    rvalue = (ae_field.datatype == "password") ? MiqAePassword.encrypt(value) : value
    value_will_change!
    @attributes['value'] = rvalue
  end

  def self.find_by_instance_id_and_field_id(inst_id, field_id)
    inst = MiqAeInstance.find(inst_id)
    inst.ae_values.detect { |f| f.field_id == field_id } if inst
  end

  def self.find_by_field_id_and_instance_id(field_id, inst_id)
    inst = MiqAeInstance.find(inst_id)
    inst.ae_values.detect { |f| f.field_id == field_id } if inst
  end

  def self.find_all_by_field_id(field_id)
    result = []
    field = MiqAeField.find(field_id)
    return result unless field
    field.ae_classes.ae_instances.collect do |inst|
      result << inst.ae_values.detect { |v| v.field_id == field_id }
    end.compact
  end

  def to_export_xml(options = {})
    require 'builder'
    xml = options[:builder] ||= ::Builder::XmlMarkup.new(:indent => options[:indent])
    xml_attrs = {:name => ae_field.name}

    self.class.column_names.each do |cname|
      # Remove any columns that we do not want to export
      next if %w(id created_on updated_on updated_by).include?(cname) || cname.ends_with?("_id")

      # Skip any columns that we process explicitly
      next if %w(name value).include?(cname)

      # Process the column
      xml_attrs[cname.to_sym]  = send(cname)   unless send(cname).blank?
    end

    xml.MiqAeField(xml_attrs) do
      value.blank? ? xml.cdata!(value.to_s) : xml.text!(value)
    end
  end
end
