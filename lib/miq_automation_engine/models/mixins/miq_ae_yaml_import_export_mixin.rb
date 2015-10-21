module MiqAeYamlImportExportMixin
  DOMAIN_YAML_FILENAME    = "__domain__.yaml"
  NAMESPACE_YAML_FILENAME = "__namespace__.yaml"
  CLASS_YAML_FILENAME     = "__class__.yaml"
  METHOD_FOLDER_NAME      = "__methods__"
  CLASS_DIR_SUFFIX        = ".class"
  DOMAIN_OBJ_TYPE         = 'domain'
  NAMESPACE_OBJ_TYPE      = 'namespace'
  CLASS_OBJ_TYPE          = 'class'
  INSTANCE_OBJ_TYPE       = 'instance'
  METHOD_OBJ_TYPE         = 'method'
  ALL_DOMAINS             = '*'
  VERSION                 = 1.0

  EXPORT_EXCLUDE_KEYS     = [/^id$/, /_id$/, /^created_on/, /^updated_on/, /^updated_by/, /^reserved$/]

  def export_attributes
    attributes.dup.delete_if { |k, _| self.class::EXPORT_EXCLUDE_KEYS.any? { |rexp| k =~ rexp } }
  end

  def export_non_blank_attributes
    attributes.dup.delete_if { |k, v| self.class::EXPORT_EXCLUDE_KEYS.any? { |rexp| k =~ rexp || v.blank? } }
  end

  def add_domain(domain_yaml, tenant)
    MiqAeDomain.create!(domain_yaml['object']['attributes'].merge(:tenant => tenant))
  end

  def add_namespace(fqname)
    MiqAeNamespace.find_or_create_by_fqname(fqname)
  end

  def add_class_schema(namespace_obj, class_yaml)
    class_attributes = class_yaml.fetch_path('object', 'attributes')
    class_attributes['namespace_id'] = namespace_obj.id
    class_schema = class_yaml.fetch_path('object', 'schema')
    MiqAeClass.new(class_attributes).tap do |class_obj|
      fields = process_fields(class_schema) unless class_schema.nil?
      class_obj.ae_fields = fields unless fields.nil?
      class_obj.save!
    end
  end

  def add_instance(class_obj, instance_yaml)
    instance_attributes = instance_yaml.fetch_path('object', 'attributes')
    instance_attributes['class_id'] = class_obj.id
    _log.info("Importing instance:  <#{instance_attributes['name']}>")
    fields = instance_yaml.fetch_path('object', 'fields')
    MiqAeInstance.new(instance_attributes).tap do |instance_obj|
      fields.each { |f| process_field_value(instance_obj, f) } unless fields.nil?
      instance_obj.save!
    end
  end

  def add_method(class_obj, method_yaml)
    method_attributes = method_yaml.fetch_path('object', 'attributes')
    _log.info("Importing method:    <#{method_attributes['name']}>")
    fields  = method_yaml.fetch_path('object', 'inputs')
    method_attributes['class_id'] = class_obj.id
    MiqAeMethod.new(method_attributes).tap do |method_obj|
      method_obj.inputs = process_fields(fields) unless fields.nil?
      method_obj.save!
    end
  end

  def process_fields(fields)
    fields.collect { |field| MiqAeField.new(field['field']) }
  end

  def process_field_value(instance_obj, field)
    field.each do |fname, value|
      ae_field = instance_obj.ae_class.ae_fields.detect { |f| fname.casecmp(f.name) == 0 }
      raise MiqAeException::FieldNotFound, "Field [#{fname}] not found in MiqAeDatastore" if ae_field.nil?
      instance_obj.ae_values << MiqAeValue.new({'ae_field' => ae_field}.merge(value))
    end
  end
end
