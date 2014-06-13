require 'util/miq-extensions'

class RhevmObject
  def self.create_from_xml(service, xml)
    self.new(service, parse_xml(xml))
  end

  def self.xml_to_relationships(xml)
    node = xml_to_nokogiri(xml)
    relationships = {}
    node.xpath('link').each do |link|
      relationships[link['rel'].to_sym] = link['href']
    end

    relationships
  end

  def self.xml_to_actions(xml)
    node = xml_to_nokogiri(xml)
    actions = {}
    node.xpath('actions/link').each do |link|
      actions[link['rel'].to_sym] = link['href']
    end

    actions
  end

  def self.hash_from_id_and_href(node)
    hash = {}
    [:id, :href].each { |key| hash[key] = node[key.to_s] unless node.nil? || node[key.to_s].nil? }
    hash
  end

  def self.parse_boolean(what)
    return true  if what == 'true'
    return false if what == 'false'
    raise "Cannot parse boolean for value: <#{what.inspect}>"
  end

  def self.parse_first_text(node, hash, key, modifier=nil)
    text_node = node.xpath(key.to_s).first
    value = text_node.text unless text_node.nil?
    self.set_value(value, hash, key, modifier)
  end

  def self.parse_attribute(node, hash, key, modifier=nil)
    value = node[key.to_s]
    self.set_value(value, hash, key, modifier)
  end

  def self.set_value(value, hash, key, modifier)
    return if value.nil?
    hash[key] = case modifier
    when :to_i    then value.to_i
    when :to_f    then value.to_f
    when :to_bool then self.parse_boolean(value)
    else value
    end
  end

  def self.parse_first_node(node, path, hash, options)
    self.parse_first_node_with_hash(node, path, nh = {}, options)
    unless nh.empty?
      hash[path.to_sym] = hash[path.to_sym].nil? ? nh : hash[path.to_sym].merge(nh)
    end
    nh
  end

  def self.parse_first_node_with_hash(node, path, hash, options)
    xnode = node.xpath(path.to_s).first
    unless xnode.blank?
      options[:attribute].to_a.each      {|key| self.parse_attribute( xnode, hash, key)}
      options[:attribute_to_i].to_a.each {|key| self.parse_attribute( xnode, hash, key, :to_i)}
      options[:attribute_to_f].to_a.each {|key| self.parse_attribute( xnode, hash, key, :to_f)}
      options[:node].to_a.each           {|key| self.parse_first_text(xnode, hash, key)}
      options[:node_to_i].to_a.each      {|key| self.parse_first_text(xnode, hash, key, :to_i)}
      options[:node_to_bool].to_a.each   {|key| self.parse_first_text(xnode, hash, key, :to_bool)}
    end
  end

  def self.top_level_objects=(keys)
    @top_level_objects = keys
  end

  def self.top_level_objects
    @top_level_objects ||= []
  end

  def self.top_level_strings=(keys)
    @top_level_strings = keys
  end

  def self.top_level_strings
    @top_level_strings ||= []
  end

  def self.top_level_integers=(keys)
    @top_level_integers = keys
  end

  def self.top_level_integers
    @top_level_integers ||= []
  end

  def self.top_level_booleans=(keys)
    @top_level_booleans = keys
  end

  def self.top_level_booleans
    @top_level_booleans ||= []
  end

  def self.top_level_timestamps=(keys)
    @top_level_timestamps = keys
  end

  def self.top_level_timestamps
    @top_level_timestamps ||= []
  end


  def self.xml_to_hash(xml)
    node                          = xml_to_nokogiri(xml)
    hash                          = hash_from_id_and_href(node)
    hash[:relationships]          = xml_to_relationships(node)
    hash[:actions]                = xml_to_actions(node)

    top_level_objects.each do |key|
      object_node = node.xpath(key.to_s).first
      hash[key]   = hash_from_id_and_href(object_node) unless object_node.nil?
    end

    top_level_strings.each do |key|
      object_node = node.xpath(key.to_s).first
      hash[key]   = object_node.text unless object_node.nil?
    end

    top_level_integers.each do |key|
      object_node = node.xpath(key.to_s).first
      hash[key]   = object_node.text.to_i  unless object_node.nil?
    end

    top_level_booleans.each do |key| 
      object_node = node.xpath(key.to_s).first
      hash[key]   = parse_boolean(object_node.text)  unless object_node.nil?
    end

    top_level_timestamps.each do |key|
      object_node = node.xpath(key.to_s).first
      hash[key]   = Time.parse(object_node.text)  unless object_node.nil?
    end

    return node, hash
  end

  def self.xml_to_nokogiri(xml)
    if xml.kind_of?(Nokogiri::XML::Element)
      nokogiri = xml
    else
      nokogiri = Nokogiri::XML(xml).root
    end
    nokogiri
  end

  def self.href_from_creation_status_link(link)
    # "/api/vms/5024ab49-19b5-4176-9568-c004d1c9f256/creation_status/d0e45003-d490-4551-9911-05b3bec682dc"
    # => "/api/vms/5024ab49-19b5-4176-9568-c004d1c9f256"
    link.split("/")[0,4].join("/")
  end

  def self.href_to_guid(href)
    href.split("/").last
  end

  def self.object_to_id(object)
    case object
    when RhevmObject
      object = object[:id]
    when String
      object = href_to_guid(object) unless object.guid?
      raise ArgumentError, "object must be a valid guid" unless object.guid?
    else
      raise ArgumentError, "object must be a valid guid or a RhevmObject"
    end
    object
  end

  def self.api_endpoint
    self.name[5..-1].pluralize.downcase
  end

  def self.element_names
    element_name.pluralize
  end

  def self.element_name
    api_endpoint.singularize
  end

  def self.all_xml_objects(service)
    response = service.resource_get(api_endpoint)
    doc      = Nokogiri::XML(response)
    objects  = doc.xpath("//#{element_names}/#{element_name}")
  end

  def self.all(service)
    all_xml_objects(service).collect { |xml| self.create_from_xml(service, xml) }
  end

  def self.find_by_name(service, name)
    all_xml_objects(service).each do |xml|
      obj = self.create_from_xml(service, xml)
      return obj if obj[:name] == name
    end
    nil
  end

  def self.find_by_id(service, id)
    find_by_href(service, "#{api_endpoint}/#{id}")
  end

  def self.find_by_href(service, href)
    response = service.resource_get(href)
    doc = Nokogiri::XML(response)
    xml = doc.xpath("//#{element_name}").first
    self.create_from_xml(service, xml)
  rescue RestClient::ResourceNotFound
    return nil
  end

  attr_accessor :attributes, :operations, :relationships, :service

  def initialize(service, options = {})
    @service       = service
    @relationships = options.delete(:relationships) || {}
    @operations    = options.delete(:actions)       || {}
    @attributes    = options
  end

  def replace(obj)
    @relationships = obj.relationships
    @operations    = obj.operations
    @attributes    = obj.attributes
  end

  def reload
    self.replace(self.class.find_by_href(@service, self[:href]))
  end

  def method_missing(m, *args)
    if @relationships.has_key?(m)
      rel_str        = m.to_s
      rel_str        = 'storage_domains' if rel_str == 'storagedomains'
      rel_str        = 'data_centers'    if rel_str == 'datacenters'
      singular       = rel_str.singularize
      require File.join(File.dirname(__FILE__), "./rhevm_#{singular}")
      klass          = "Rhevm#{singular.camelize}".constantize
      xml            = @service.resource_get(@relationships[m])
      doc            = Nokogiri::XML(xml)
      return doc.root.xpath(singular).collect { |node| klass.create_from_xml(@service, node) }
    end

    return operation(m, args) if @operations.has_key?(m)

    super
  end

  def operation(method, *args)
    if @operations.has_key?(method.to_sym)
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.action { yield xml if block_given? }
      end
      data = builder.doc.root.to_xml

      @service.resource_post(@operations[method.to_sym], data)
    else
      raise "Method:<#{method}> is not available for object <#{self.class.name}>"
    end
  end

  def destroy
    @service.resource_delete(@attributes[:href])
  end

  def class_suffix
    self.class.name[5..-1]
  end

  def api_endpoint
    self[:href] || "#{self.class.api_endpoint}/#{self[:id]}"
  end

  def update!(&block)
    response = update(&block)

    obj = self.class.create_from_xml(@service, response)
    self.replace(obj)
  end

  def update
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.send(self.class_suffix.downcase) { yield xml if block_given? }
    end
    data = builder.doc.root.to_xml

    @service.resource_put(api_endpoint, data)
  end

  def keys
    @attributes.keys
  end

  def [](key)
    @attributes[key]
  end
end
