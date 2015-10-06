require 'util/miq-xml'
require 'util/miq-logger'

class ScanProfilesBase
  def self.get_class(type, from)
    k = from.instance_variable_get("@scan_#{type}_class")
    return k unless k.nil?

    k = "#{from.name.underscore.split('_')[0..-2].join('_').camelize}#{type.camelize}"
    require k
    from.instance_variable_set("@scan_#{type}_class", Object.const_get(k))
  end

  def self.scan_item_class;     get_class('item',    self); end

  def self.scan_profile_class;  get_class('profile', self); end

  def self.scan_profiles_class; self; end

  include Enumerable

  attr_accessor :profiles

  def initialize(dataHash, options = {})
    @params = dataHash
    @options = options
    @xml_class = @options[:xml_class] || XmlHash::Document
    @profiles = @params.nil? ? [] : @params.collect { |p| self.class.scan_profile_class.new(p, @options) }
  end

  def each
    profiles.each { |p| yield p }
  end

  def each_scan_definition(type = nil, &blk)
    profiles.each { |p| p.each_scan_definition(type, &blk) }
  end

  def each_scan_item(type = nil, &blk)
    profiles.each { |p| p.each_scan_item(type, &blk) }
  end

  def parse_data(obj, data, &blk)
    each_scan_item { |si| si.parse_data(obj, data, &blk) }
  end

  def to_xml
    xml = @xml_class.createDoc("<scan_profiles/>")
    each { |p| xml.root << p.to_xml }
    xml
  end

  def to_hash
    {:scan_profiles => collect(&:to_hash)}
  end

  def to_yaml
    YAML.dump(to_hash)
  end
end
