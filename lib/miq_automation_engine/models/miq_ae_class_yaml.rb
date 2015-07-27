class MiqAeClassYaml
  attr_accessor :ae_class_obj
  def initialize(filename = nil)
    @filename     = filename
    @ae_class_obj = YAML.load_file(filename) if filename
  end

  def field_names
    raise "class object has not been set" unless @ae_class_obj
    @ae_class_obj['object']['schema'].collect { |x| x['field']['name'].downcase }
  end

  def field_hash(name)
    raise "class object has not been set" unless @ae_class_obj
    field = @ae_class_obj['object']['schema'].detect { |f| f['field']['name'].casecmp(name) == 0 }
    raise "field #{name} not found in yaml class #{@filename}" if field.nil?
    field['field']
  end
end
