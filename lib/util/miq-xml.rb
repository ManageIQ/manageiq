$:.push("#{File.dirname(__FILE__)}/xml")
require 'time'
require 'xml/miq_rexml'
require 'xml/xml_hash'
require 'miq-encode'
require 'xml/xml_diff'
require 'xml/xml_patch'

class MiqXml  
	#MIQ_XML_VERSION = 1.0
	#MIQ_XML_VERSION = 1.1	# Added create_time to root in seconds for easier time conversions
	MIQ_XML_VERSION = 2.0	# Changed sub-xmls, added namespaces

	@@defaultXmlType = :rexml  # REXML is always available so default it here.

  # Now test to see if nokogiri is available
  @@nokogiri_loaded = false
	begin
    require 'miq_nokogiri'
  	Nokogiri::XML::Document.new
    #@@defaultXmlType = :nokogiri
		@@nokogiri_loaded = true
  rescue
  end

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
      when :rexml then REXML::Document
      when :xmlhash then XmlHash::Document
      when :nokogiri then Nokogiri::XML::Document
      else REXML::Document
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
