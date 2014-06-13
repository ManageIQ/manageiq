$:.push("#{File.dirname(__FILE__)}/modules")

class ScanItemBase
  SCAN_TYPE_PROP = "item_type"

  attr_accessor :scan_definition, :scan_item_type

  def self.scan_profile_class;  ScanProfilesBase.get_class('profile',  self); end
  def self.scan_profiles_class; ScanProfilesBase.get_class('profiles', self); end
  def self.scan_item_class;     self; end

  def initialize(dataHash, options={})
    @params = dataHash
    @options = options
    @xml_class = @options[:xml_class] || XmlHash::Document

    @scan_item_type = @params[SCAN_TYPE_PROP]
    self.extend_scan_module(@scan_item_type)

    @scan_definition = @params[ScanProfileBase::DEFINITION]
  end

  def extend_scan_module(type)
    raise "Already set scan module" if @extend_scan_module
    begin
      m = "#{self.class.name}#{type.capitalize}"
      require m
      extend Object.const_get(m)
    rescue LoadError
    end
    @extend_scan_module = true
  end

  def with_scan_definition(type=nil)
    yield self.scan_definition if type.nil? || type == self.scan_item_type
  end

  # THESE METHODS SHOULD BE OVER-RIDDEN BY THE REQUIRES IN THE INITIALIZER
  def to_xml
    xml = @xml_class.newNode("scan_item")
    xml.add_attributes(
      "guid" => @params["guid"],
      "name" => @params["name"],
      "item_type" => @params["item_type"])
    return xml
  end

  def to_hash
    return {
      :guid => @params["guid"],
      :name => @params["name"],
      :item_type => @params["item_type"]
    }
  end

  def to_yaml
    return YAML.dump(self.to_hash)
  end

  def parse_data(obj, data, &blk)
    nil
  end
end
