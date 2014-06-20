class MiqAeInstanceYaml
  attr_accessor :ae_instance_obj
  def initialize(filename = nil)
    @filename = filename
    @ae_instance_obj = YAML.load_file(@filename) if @filename
  end

  def field_names
    raise "ae instance object has not been initialize" unless @ae_instance_obj
    @ae_instance_obj['object']['fields'].collect { |item| item.keys }.flatten
  end

  def field_value_hash(name)
    raise "ae instance object has not been initialize" unless @ae_instance_obj
    value = @ae_instance_obj['object']['fields'].detect { |item| item.keys[0].casecmp(name) == 0 }
    raise "field name #{name} not found in instance #{@filename}" if value.nil?
    value[name]
  end
end
