class MiqAeField < MiqAeBase
  include MiqAeModelBase
  include MiqAeFsStore
  expose_columns :method_id, :class_id
  expose_columns :description, :display_name, :name
  expose_columns :on_entry, :on_exit, :on_error, :max_retries, :max_time, :collect, :message
  expose_columns :id, :created_on, :created_by_user_id
  expose_columns :updated_on, :updated_by, :updated_by_user_id
  expose_columns :aetype, :datatype, :priority, :default_value, :substitute
  expose_columns :owner, :visibility, :scope

  validate :presence_of_parent, :on => :create
  validates_format_of     :name, :with => /\A[A-Za-z0-9_]+\z/i

  validates_inclusion_of :substitute, :in => [true, false], :allow_nil => true
  AVAILABLE_SCOPES    = %w(class instance local)
  validates_inclusion_of :scope,      :in => AVAILABLE_SCOPES,    :allow_nil => true
  AVAILABLE_AETYPES   = %w(assertion attribute method relationship state)
  validates_inclusion_of :aetype,     :in => AVAILABLE_AETYPES,   :allow_nil => true
  AVAILABLE_DATATYPES_FOR_UI = %w(string symbol integer float boolean time array password)
  EXTRA_DATATYPES = %w(host vm storage ems policy server request provision)
  AVAILABLE_DATATYPES        = AVAILABLE_DATATYPES_FOR_UI + EXTRA_DATATYPES
  validates_inclusion_of :datatype,   :in => AVAILABLE_DATATYPES, :allow_nil => true

  validate :uniqueness_of_field_name, :on => :create

  DEFAULTS = {:substitute => true,
              :datatype   => "string",
              :aetype     => "attribute",
              :scope      => "instance",
              :message    => "create"}

  BASE_ATTRIBUTES  = %w(aetype datatype priority default_value substitute messsage)
  OWNER_ATTRIBUTES = %w(owner visibility class_id method_id scope)

  def self.column_names
    %w(method_id class_id description display_name name
       on_entry on_exit on_error max_retries max_time collect message
       id created_on created_by_user_id updated_on updated_by_user_id
       aetype datatype priority default_value substitute
       owner visibility scope)
  end

  def self.base_class
    MiqAeField
  end

  def self.base_model
    MiqAeField
  end

  def self.count
    MiqAeDomain.fetch_count(MiqAeField)
  end

  def ae_values
    @values_proxy ||= MiqAeHasManyProxy.new(MiqAeValue, load_all_values)
  end

  def ae_class
    return nil unless class_id
    @ae_class ||= MiqAeClass.find(class_id)
  end

  def ae_class=(obj)
    @ae_class = obj
    @attributes[:class_id]  = obj.id
  end

  def ae_method
    return nil unless method_id
    @ae_method ||= MiqAeMethod.find(method_id)
  end

  def ae_method=(obj)
    @ae_method = obj
    @attributes[:method_id]  = obj.id
  end

  def editable?
    parent_obj.ae_namespace.editable?
  end

  def initialize(options = {})
    @attributes = HashWithIndifferentAccess.new(options)
    self.default_value = @attributes.delete(:default_value) if @attributes.key?(:default_value)
    self.ae_method = @attributes.delete(:ae_method) if @attributes.key?(:ae_method)
    self.ae_class = @attributes.delete(:ae_class) if @attributes.key?(:ae_class)
    self.substitute = @attributes.fetch(:substitute, true)
  end

  def destroy
    delete_field_values_from_instances if ae_class
    items_deleted = parent_fields.reject! { |f| f.id == id }
    return unless items_deleted

    parent_obj.children_deleted
    parent_obj.save
  end

  def presence_of_parent
    errors.add(:class_id, "Field #{name} has no parent") if method_id.nil? && class_id.nil?
  end

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

  def self.find(id)
    return nil if id.blank?
    parts = id.split('#')
    return nil unless parts.length == 2
    find_by_name_and_class_id(parts[1], parts[0]) || find_by_name_and_method_id(parts[1], parts[0])
  end

  def self.find_all_by_id(ids)
    ids.collect { |id| find(id) }
  end

  def self.find_by_id(id)
    find(id)
  end

  def self.find_by_name_and_class_id(name, class_id)
    class_obj = MiqAeClass.find(class_id)
    return nil unless class_obj
    class_obj.ae_fields.detect { |f| f.name.casecmp(name) == 0 }
  end

  def self.find_all_by_class_id(class_id)
    cls = MiqAeClass.find(class_id)
    cls ?  cls.ae_fields : []
  end

  def self.find_by_name_and_method_id(name, method_id)
    meth_obj = MiqAeMethod.find(method_id)
    return nil unless meth_obj
    meth_obj.inputs.detect { |f| f.name.casecmp(name) == 0 }
  end

  def default_value=(value)
    write_default_value(value)
  end

  def to_export_yaml
    {"field" => export_attributes}
  end

  def set_message_and_default_value
    self.message ||= DEFAULTS[:message]
    write_default_value(default_value)
  end

  def save
    # raise "Save called directly for field"
    context = persisted? ? :update : :create
    generate_id   unless id
    return false unless valid?(context)
    set_message_and_default_value
    apply_changes(context)
    parent_obj.save
  end

  def auto_save
    context = persisted? ? :update : :create
    generate_id   unless id
    set_message_and_default_value
    valid?(context)
  end

  def apply_changes(context)
    old_field = parent_fields.detect { |f| f.id == id }
    if context == :create
      parent_fields << self unless old_field
    elsif context == :update && object_id != old_field.object_id
      attributes.each { |k, v| old_field[k] = v }
    end
  end

  def uniqueness_of_field_name
    return false unless parent_obj
    unless name
      errors.add(:name, "field name cannot be blank")
      return false
    end
    x = parent_fields.detect { |f| f.name.casecmp(name) == 0 }
    return true unless x
    return true if x == self
    errors.add(:name, "#{name} already in use")
    false
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
    # Any invalid boolean string should be converted to default
    @attributes[:substitute] = if TRUE_VALUES.include?(value)
                                 true
                               elsif FALSE_VALUES.include?(value)
                                 false
                               else
                                 DEFAULTS[:substitute]
                               end
  end

  private

  def write_default_value(value)
    @attributes[:default_value] =  (datatype == "password") ? MiqAePassword.encrypt(value) : value
  end

  def generate_id
    self.id = "#{parent_obj.id}##{name}"
  end

  def parent_obj
    ae_class || ae_method
  end

  def parent_fields
    ae_class ? ae_class.ae_fields : ae_method.inputs
  end

  def load_all_values
    matching_values = []
    ae_class.ae_instances.each do |inst|
      inst.ae_values.each do |val|
        matching_values << val if val.field_id == id
      end
    end
    matching_values
  end

  def delete_field_values_from_instances
    ae_class.ae_instances.each do |inst|
      items_deleted = inst.ae_values.reject! { |v| v.field_id == id }
      inst.save if items_deleted
    end
  end
end
