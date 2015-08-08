require 'time'
require 'util/xml/miq_rexml'
require 'util/xml/xml_hash'
require 'util/miq-encode'
require 'util/xml/xml_diff'
require 'util/xml/xml_patch'

class MiqXml
  MIQ_XML_VERSION = 3.0 # Use Nokogiri by default

  DefaultXmlType = :nokogiri

  @rexml_parser = false

  def self.loadFile(filename, xmlClass = DefaultXmlType)
    xml_document(xmlClass).loadFile(filename)
  end

  def self.load(data, xmlClass = DefaultXmlType)
    xml_document(xmlClass).load(data)
  end

  def self.createDoc(rootName, rootAttrs = nil, version = MIQ_XML_VERSION, xmlClass = DefaultXmlType)
    xml_document(xmlClass).createDoc(rootName, rootAttrs, version)
  end

  def self.newDoc(xmlClass = DefaultXmlType)
    xml_document(xmlClass).newDoc()
  end

  def self.decode(encodedText, xmlClass = DefaultXmlType)
    return xml_document(xmlClass).load(MIQEncode.decode(encodedText)) if encodedText
    newDoc()
  end

  def self.newNode(data=nil, xmlClass = DefaultXmlType)
    xml_document(xmlClass).newNode(data)
  end

  def self.xml_document(xmlClass)
    return xmlClass::Document if xmlClass.kind_of?(Module)
    begin
      case xmlClass
      when :rexml
        @rexml_parser = true
        REXML::Document
      when :xmlhash
        XmlHash::Document
      when :nokogiri
        require 'util/xml/miq_nokogiri'
        Nokogiri::XML::Document
      else
        REXML::Document
      end
    rescue
      REXML::Document
    end
  end

  def self.isXmlElement?(handle)
    return true if handle.kind_of?(Nokogiri::XML::Node)
    return true if rexml_parser? && handle.kind_of?(REXML::Element) || handle.kind_of?(XmlHash::Element)
    false
  end

  def self.isXmlDoc?(handle)
    return true if handle.kind_of?(Nokogiri::XML::Document)
    return true if rexml_parser? && handle.kind_of?(REXML::Document) || handle.kind_of?(XmlHash::Document)
    false
  end

  def self.isXml?(handle)
    return true if (handle.kind_of?(Nokogiri::XML::Element) || handle.kind_of?(Nokogiri::XML::Document))
    return true if rexml_parser? && handle.kind_of?(REXML::Element) || handle.kind_of?(REXML::Document) || handle.kind_of?(XmlHash::Element) || handle.kind_of?(XmlHash::Document)
    false
  end

  def self.rexml_parser?
    @rexml_parser
  end
end
