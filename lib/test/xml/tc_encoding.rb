$:.push("#{File.dirname(__FILE__)}")
$:.push("#{File.dirname(__FILE__)}/../../util/")
require 'rubygems'
require 'test/unit'
require 'miq-xml'

class XmlEncoding < Test::Unit::TestCase

  def test_attribute_encoding
    xml = REXML::Document.new("<test/>")
    attr_string = "string \xC2\xAE"
    xml.root.add_element("element_1", {'attr1' => attr_string})
    assert(attr_string, xml.root.elements[1].attributes['attr1'])
  end

  def test_load_document_encoding
    attr_string = "string \xC2\xAE"
    doc_text = "<test><element_1 attr1='#{attr_string}'/></test>"
    xml = MiqXml.load(doc_text)
    assert(attr_string, xml.root.elements[1].attributes['attr1'])
  end

  def test_load_document_with_bom
    attr_string = "test string"
    doc_text = "\xC3\xAF\xC2\xBB\xC2\xBF<test><element_1 attr1='#{attr_string}'/></test>"
    xml = MiqXml.load(doc_text)
    assert(attr_string, xml.root.elements[1].attributes['attr1'])

    assert("\xC3\xAF\xC2\xBB\xC2\xBF", xml.to_s[0,3])
    xml.write(xml_str='', 1)
    assert("\xC3\xAF\xC2\xBB\xC2\xBF", xml_str[0,3])
  end

end
