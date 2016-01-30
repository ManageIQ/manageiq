class ScanProfileBase
  def self.scan_item_class;     ScanProfilesBase.get_class('item',     self); end

  def self.scan_profiles_class; ScanProfilesBase.get_class('profiles', self); end

  def self.scan_profile_class;  self; end

  include Enumerable

  DEFINITION = "definition"

  attr_accessor :scan_items

  def initialize(dataHash, options = {})
    @params = dataHash
    @options = options
    @xml_class = @options[:xml_class] || XmlHash::Document
    @scan_items = @params[DEFINITION].collect { |s| self.class.scan_item_class.new(s, options) }
  end

  def each
    scan_items.each { |si| yield si }
  end

  def each_scan_definition(type = nil, &blk)
    scan_items.each { |si| si.with_scan_definition(type, &blk) if type.nil? || type == si.scan_item_type }
  end

  def each_scan_item(type = nil)
    scan_items.each { |si| yield si if type.nil? || type == si.scan_item_type }
  end

  def to_xml
    xml = @xml_class.newNode("scan_profile")
    xml.add_attributes("guid" => @params["guid"], "name" => @params["name"])
    each { |si| xml << si.to_xml }
    xml
  end

  def to_hash
    {
      :guid       => @params["guid"],
      :name       => @params["name"],
      :scan_items => collect(&:to_hash)
    }
  end

  def to_yaml
    YAML.dump(to_hash)
  end
end
