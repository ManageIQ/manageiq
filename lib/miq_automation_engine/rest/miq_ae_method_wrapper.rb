require 'yaml'
require 'json'
require 'byebug'
require 'rest-client'
require_relative 'miq_ae_method_vmdb_object'

class MiqAeMethodWrapper
  attr_accessor :root, :inputs, :object
  attr_accessor :current_namespace
  attr_accessor :current_class
  attr_accessor :current_instance
  attr_accessor :current_message
  attr_accessor :current_method
  attr_reader   :token

  def initialize
    @token = MIQ_METHOD_TOKEN
    @base_url = ENV['MIQ_METHOD_BASE_URL'] || 'http://localhost:4000'
    hash = YAML.load_file(MIQ_INPUT_FILE)
    @output_file = MIQ_OUTPUT_FILE
    @root = MiqAeMethodObject.new(self, nil, hash[:workspace].first)
    @inputs = hash[:inputs]
    @persist_state_hash = hash[:state_var] || {}
    initialize_api
    load_current_info(hash[:current])
  end

  def log(level, message)
    case level
    when 'error', :error
      STDERR.puts "AE Method #{current_method} #{message}"
    when 'warn', 'info', :warn, :info
      STDOUT.puts "AE Method #{current_method} #{message}"
    end
  end

  # TODO: Get the URL to map this new class
  def vmdb(_klass, _id)
    raise "Not yet implemented"
  end

  def get_json(href)
    url = href.start_with?(@base_url) ? href : "#{@base_url}#{href}"
    options = {:method  => :get,
               :url     => url,
               :headers => {'X-Auth-Token' => @token}}

    body = RestClient::Request.new(options).execute.body
    JSON.parse(body)
  end

  def get_object(href)
    MiqAeMethodVmdbObject.new(self, get_json(href))
  end

  def set_state_var(name, value)
    @persist_state_hash[name] = value
  end

  def state_var_exist?(name)
    @persist_state_hash.key?(name)
  end

  def get_state_var(name)
    @persist_state_hash[name]
  end

  def save_workspace
    updated_ws = {'workspace' => root.to_hash_with_refs,
                  'state_var' => @persist_state_hash}.to_yaml
    open(@output_file, 'w') { |f| f.puts updated_ws }
  end

  def current_object=(obj)
    @object ||= obj
  end

  def current_object
    @object
  end

  private

  def initialize_api
    options = {:method  => :get,
               :url     => "#{@base_url}/api",
               :headers => {'X-Auth-Token' => @token}}

    body = RestClient::Request.new(options).execute.body
    @apis = JSON.parse(body)['collections']
  end

  def load_current_info(hash)
    @current_namespace = hash['current_namespace']
    @current_class = hash['current_class']
    @current_instance = hash['current_instance']
    @current_method = hash['current_method']
    @current_message = hash['current_message']
  end
end

class MiqAeMethodObject
  def initialize(wrapper, parent = nil, hash = {})
    @wrapper   = wrapper
    @namespace = hash['namespace']
    @klass     = hash['class']
    @instance  = hash['instance']
    @attributes = hash['attributes'] || {}
    load_references(hash['references'])
    @parent     = parent
    @children = load_children(hash['MiqAeObject'])
    @updated_attrs = []
    @updated_refs  = []
    @wrapper.current_object = self
  end

  def load_references(hash)
    return unless hash
    hash.each do |attr_name, href|
      @attributes[attr_name] = @wrapper.get_object(href)
    end
  end

  def attributes
    @attributes.clone
  end

  def load_children(objects)
    return [] unless objects
    objects.collect { |obj| MiqAeMethodObject.new(@wrapper, self, obj) }
  end

  def [](attr)
    value = @attributes[attr.downcase]
    # TODO: How to deal password
    # value = value.to_s if value.kind_of?(MiqAePassword)
    value
  end

  def []=(attr, value)
    attr = attr.downcase
    value.class == MiqAeMethodVmdbObject ? update_ref(attr, value) : update_attr(attr, value)
  end

  def to_hash_with_refs
    result = {
      "namespace"   => @namespace,
      "class"       => @klass,
      "instance"    => @instance,
      "attributes"  => updated_attributes,
      "references"  => updated_references,
      "MiqAeObject" => @children.collect(&:to_hash_with_refs)
    }
    result.delete_if { |_k, v| v.nil? }
  end

  private

  def update_attr(attr, value)
    unless @attributes[attr] == value
      @attributes[attr] = value
      @updated_attrs << attr unless @updated_attrs.include?(attr)
    end
  end

  def update_ref(attr, value)
    @attributes[attr] = value
    @updated_refs << attr unless @updated_refs.include?(attr)
  end

  def updated_attributes
    @updated_attrs.each_with_object({}) { |k, hash| hash[k] = @attributes[k] }
  end

  def updated_references
    @updated_refs.each_with_object({}) { |k, hash| hash[k] = @attributes[k].href }
  end
end
