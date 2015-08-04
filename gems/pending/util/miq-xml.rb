require 'time'
require 'util/xml/miq_rexml'
require 'util/xml/xml_hash'
require 'util/miq-encode'
require 'util/xml/xml_diff'
require 'util/xml/xml_patch'

class MiqXml
  MIQ_XML_VERSION = 2.0 # Changed sub-xmls, added namespaces

  @@defaultXmlType = :rexml  # REXML is always available so default it here.

  # Set to true if nokogiri is set as parser.
  @@nokogiri_loaded = false

  def self.loadFile(filename, xmlClass = @@defaultXmlType)
    self.xml_document(xmlClass).loadFile(filename)
  end

  def self.load(data, xmlClass = @@defaultXmlType)
    self.xml_document(xmlClass).load(data)
  end

  def self.createDoc(rootName, rootAttrs = nil, version = MIQ_XML_VERSION, xmlClass = @@defaultXmlType)
    self.xml_document(xmlClass).createDoc(rootName, rootAttrs, version)
  end

  def self.newDoc(xmlClass = @@defaultXmlType)
    self.xml_document(xmlClass).newDoc()
  end

  def self.decode(encodedText, xmlClass = @@defaultXmlType)
    return self.xml_document(xmlClass).load(MIQEncode.decode(encodedText)) if encodedText
    self.newDoc()
  end

  def self.newNode(data=nil, xmlClass = @@defaultXmlType)
    self.xml_document(xmlClass).newNode(data)
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
        @@nokogiri_loaded = true
        Nokogiri::XML::Document
      else
        REXML::Document
      end
    rescue
      REXML::Document
    end
  end

  def self.isXmlElement?(handle)
    return true if handle.is_a?(REXML::Element) || handle.is_a?(XmlHash::Element)
    return true if @@nokogiri_loaded && handle.kind_of?(Nokogiri::XML::Node)
    false
  end

  def self.isXmlDoc?(handle)
    return true if handle.is_a?(REXML::Document) || handle.is_a?(XmlHash::Document)
    return true if @@nokogiri_loaded && handle.is_a?(Nokogiri::XML::Document)
    false
  end

  def self.isXml?(handle)
    return true if handle.is_a?(REXML::Element) || handle.is_a?(REXML::Document) || handle.is_a?(XmlHash::Element) || handle.is_a?(XmlHash::Document)
    return true if @@nokogiri_loaded && (handle.is_a?(Nokogiri::XML::Element) || handle.is_a?(Nokogiri::XML::Document))
    false
  end

  def self.is_nokogiri_loaded?
    @@nokogiri_loaded
  end
end
