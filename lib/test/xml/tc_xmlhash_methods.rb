$:.push("#{File.dirname(__FILE__)}")
$:.push("#{File.dirname(__FILE__)}/../../util/")
require 'rubygems'
require 'test/unit'
require 'miq-xml'
require 'xmlsimple'

class TestXmlHashMethods < Test::Unit::TestCase
  require 'xml_base_parser_tests'
  include XmlBaseParserTests

  # Remove test that are not supported
  undef_method :test_find_each, :test_find_first, :test_find_match

  # TODO: Fix deletion of elements while looping over them
  undef_method :test_node_loop_and_move
  
  undef_method :test_deep_clone

	def setup
    @xml_klass = XmlHash
    @xml_string = self.default_test_xml()
    @xml = MiqXml.load(@xml_string, @xml_klass)
	end

	def teardown
	end

  def test_attribute()
    xml = @xml
    assert_kind_of(@xml_klass::Document, xml)

    node = xml.root.elements[1].elements[1]
    assert_equal(true, node.attributes.has_key?(:type))

    attrs = xml.root.attributes.to_h
    assert_kind_of(Hash, attrs)
    assert_equal(0, attrs.length)

    attrs = node.attributes.to_h
    assert_kind_of(Hash, attrs)
    assert_equal(3, attrs.length)

    count = 0
    node.attributes.each_pair do |k,v|
      assert_not_nil(k)
      assert_instance_of(Symbol, k)
      assert_not_nil(v)
      assert_instance_of(String, v)
      count += 1
    end
    assert_equal(3, count)
    
    count = 0
    node.attributes.to_h.each do|k,v|
      assert_not_nil(k)
      assert_instance_of(Symbol, k)
      assert_not_nil(v)
      count += 1
    end
    assert_equal(3, count)

    node.attributes.to_h.each do|k,v|
      assert_instance_of(Symbol, k)
    end

#    node.attributes.to_h(true).each do|k,v|
#      assert_instance_of(Symbol, k)
#    end
#
#    node.attributes.to_h(false).each do|k,v|
#      assert_instance_of(String, k)
#    end

    e1 = e2 = node
    e1.attributes.each_pair do |k, v|
      assert_equal(false, v.to_s != e2.attributes[k])
    end

    e1.attributes.each_key do |k|
      assert_instance_of(Symbol, k)
    end    
  end

  def test_create_new_doc()
    xml_new = MiqXml.newDoc(@xml_klass)
    assert_nil(xml_new.root)
    xml_new.add_element('root')
    assert_not_nil(xml_new.root)
    assert_equal("root", xml_new.root.name.to_s)

    new_node = xml_new.root.add_element("node1", "enabled"=>true, "disabled"=>false, "nothing"=>nil)

    assert_equal(true, MiqXml.isXmlElement?(new_node))
    assert_equal(false, MiqXml.isXmlElement?(nil))

    attrs = new_node.attributes
    assert_equal("true", attrs["enabled"].to_s)
    assert_equal("false", attrs["disabled"].to_s)
    assert_nil(attrs["nothing"])
    new_node.add_attributes("nothing"=>"something")
    assert_equal("something", new_node.attributes["nothing"].to_s)

    assert_kind_of(@xml_klass::Document, xml_new.document)
    assert_kind_of(@xml_klass::Document, xml_new.doc)
    assert_not_equal(@xml_klass::Document, xml_new.root.class)
    assert_kind_of(@xml_klass::Document, xml_new.root.doc)
    assert_equal(xml_new.document, xml_new.doc)
    assert_kind_of(@xml_klass::Document, xml_new.root.doc)
    assert_not_equal(@xml_klass::Document, xml_new.root.root.class)

    # Create an empty document with the utf-8 encoding
    # During assert allow for single quotes and new line char.
    xml_new = MiqXml.createDoc(nil, nil, nil, @xml_klass)
    #TODO: This method does not return the expected empty document header
    #assert_equal("<?xml version='1.0' encoding='UTF-8'?>", xml_new.to_xml.to_s.gsub("\"", "'").chomp)
  end

  def test_create_new_node()
    node = MiqXml.newNode("scan_item", @xml_klass)
    assert_equal("<scan_item/>", node.to_xml.to_s)
    node = MiqXml.newNode(nil, @xml_klass)
    #TODO: This method does not return the expected empty node text
    #assert_equal("</>", node.to_xml.to_s)
  end
  
  def test_xml_simple()
    simple_xml_text = <<-EOL
    <MiqAeDatastore>
      <MiqAeClass name="AUTOMATE" namespace="EVM">
        <MiqAeSchema>
          <MiqAeField name="discover" aetype="relation" default_value="" display_name="Discovery Relationships"/>
        </MiqAeSchema>
        <MiqAeInstance name="aevent">
          <MiqAeField name="discover">//evm/discover/${//workspace/aevent/type}</MiqAeField>
        </MiqAeInstance>
      </MiqAeClass>
      <MiqAeClass name="DISCOVER" namespace="EVM">
        <MiqAeSchema>
          <MiqAeField name="os" aetype="attribute" default_value=""/>
        </MiqAeSchema>
        <MiqAeInstance name="vm">
          <MiqAeField name="os">this should be a method to get the OS if it is not in the inbound object</MiqAeField>
        </MiqAeInstance>
        <MiqAeInstance name="host">
          <MiqAeField name="os" value="sometimes"/>
        </MiqAeInstance>
      </MiqAeClass>
    </MiqAeDatastore>
    EOL

    h = XmlSimple.xml_in(simple_xml_text)
    h2 = XmlHash.load(simple_xml_text).to_h(:symbols=>false)
    assert_equal(h.inspect.length, h2.inspect.length)

    xml = XmlHash.from_hash(h2, {:rootname => "MiqAeDatastore"})

    assert_respond_to(xml, :xmlDiff)
    assert_respond_to(xml, :xmlPatch)
    xml_old = XmlHash.load(simple_xml_text)
    stats = {}
    xml_diff = xml.xmlDiff(xml_old, stats)
    assert_equal(0, stats[:adds])
    assert_equal(0, stats[:deletes])
    assert_equal(0, stats[:updates])
  end

  def test_cdata()
    xml = MiqXml.newDoc(@xml_klass)
    xml.add_element('root')

    time = Time.now
		html_text = "<b>#{time}</b>"
    xml.root.add_cdata(html_text.gsub(",","\\,"))

    assert(xml.to_xml.to_s.include?("![CDATA[<b>#{time}</b>]]"))
    assert_equal("<b>#{time}</b>", xml.root.text)
  end
end
