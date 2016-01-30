require 'time'
require 'util/xml/miq_rexml'
require 'util/xml/xml_hash'
require 'util/miq-encode'
require 'util/xml/xml_diff'
require 'util/xml/xml_patch'

class MiqXml
  MIQ_XML_VERSION = 2.1 # Refactor Nokogiri handling

  DEFAULT_XML_TYPE = :rexml # REXML is always available so default it here.

  @nokogiri = false

  def self.loadFile(filename, xmlClass = DEFAULT_XML_TYPE)
    xml_document(xmlClass).loadFile(filename)
  end

  def self.load(data, xmlClass = DEFAULT_XML_TYPE)
    xml_document(xmlClass).load(data)
  end

  def self.createDoc(rootName, rootAttrs = nil, version = MIQ_XML_VERSION, xmlClass = DEFAULT_XML_TYPE)
    xml_document(xmlClass).createDoc(rootName, rootAttrs, version)
  end

  def self.newDoc(xmlClass = DEFAULT_XML_TYPE)
    xml_document(xmlClass).newDoc
  end

  def self.decode(encodedText, xmlClass = DEFAULT_XML_TYPE)
    return xml_document(xmlClass).load(MIQEncode.decode(encodedText)) if encodedText
    newDoc
  end

  def self.newNode(data = nil, xmlClass = DEFAULT_XML_TYPE)
    xml_document(xmlClass).newNode(data)
  end

  def self.xml_document(xmlClass)
    return xmlClass::Document if xmlClass.kind_of?(Module)
    begin
      case xmlClass
      when :rexml
        REXML::Document
      when :xmlhash
        XmlHash::Document
      when :nokogiri
        require 'util/xml/miq_nokogiri'
        @nokogiri = true
        Nokogiri::XML::Document
      else
        REXML::Document
      end
    rescue
      REXML::Document
    end
  end

  def self.isXmlElement?(handle)
    return true if handle.kind_of?(REXML::Element) || handle.kind_of?(XmlHash::Element)
    return true if nokogiri? && handle.kind_of?(Nokogiri::XML::Node)
    false
  end

  def self.isXmlDoc?(handle)
    return true if handle.kind_of?(REXML::Document) || handle.kind_of?(XmlHash::Document)
    return true if nokogiri? && handle.kind_of?(Nokogiri::XML::Document)
    false
  end

  def self.isXml?(handle)
    return true if handle.kind_of?(REXML::Element) || handle.kind_of?(REXML::Document) || handle.kind_of?(XmlHash::Element) || handle.kind_of?(XmlHash::Document)
    return true if nokogiri? && (handle.kind_of?(Nokogiri::XML::Element) || handle.kind_of?(Nokogiri::XML::Document))
    false
  end

  def self.nokogiri?
    @nokogiri
  end
end
