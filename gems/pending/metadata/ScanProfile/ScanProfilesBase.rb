$:.push("#{File.dirname(__FILE__)}/../../../util")

require 'miq-xml'
require 'miq-logger'

class ScanProfilesBase
  def self.get_class(type, from)
    k = from.instance_variable_get("@scan_#{type}_class")
    return k unless k.nil?

    k = "#{from.name.underscore.split('_')[0..-2].join('_').camelize}#{type.camelize}"
    require k
    from.instance_variable_set("@scan_#{type}_class", Object.const_get(k))
  end

  def self.scan_item_class;     self.get_class('item',    self); end
  def self.scan_profile_class;  self.get_class('profile', self); end
  def self.scan_profiles_class; self; end

  include Enumerable

  attr_accessor :profiles

  def initialize(dataHash, options={})
    @params = dataHash
    @options = options
    @xml_class = @options[:xml_class] || XmlHash::Document
    @profiles = @params.nil? ? [] : @params.collect {|p| self.class.scan_profile_class.new(p, @options)}
  end

  def each
    self.profiles.each { |p| yield p }
  end

  def each_scan_definition(type=nil, &blk)
    self.profiles.each { |p| p.each_scan_definition(type, &blk) }
  end

  def each_scan_item(type=nil, &blk)
    self.profiles.each { |p| p.each_scan_item(type, &blk) }
  end

  def parse_data(obj, data, &blk)
    self.each_scan_item { |si| si.parse_data(obj, data, &blk) }
  end

  def to_xml
    xml = @xml_class.createDoc("<scan_profiles/>")
    self.each {|p| xml.root << p.to_xml }
    return xml
  end

  def to_hash
    return {:scan_profiles => self.collect(&:to_hash) }
  end

  def to_yaml
    return YAML.dump(self.to_hash)
  end
end
