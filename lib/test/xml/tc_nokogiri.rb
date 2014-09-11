$:.push("#{File.dirname(__FILE__)}")
$:.push("#{File.dirname(__FILE__)}/../../util/")
require 'rubygems'
require 'test/unit'
require 'miq-xml'
require 'nokogiri'

class NokogiriXmlMethods < Test::Unit::TestCase
#  require 'xml_base_parser_tests'
#  include XmlBaseParserTests

	def setup
    @xml_klass = Nokogiri::XML
    @xml_string = self.default_test_xml() if @xml_string.nil?
    @xml = MiqXml.load(@xml_string, @xml_klass)
	end

	def teardown
	end

  def default_test_xml()
    xml_string = <<-EOL
      <?xml version='1.0' encoding='UTF-8'?>
      <rows>
        <head>
          <column width='10' type='link' sort='str'>Name</column>
          <column width='10' type='ro' sort='str'>Host Name</column>
          <column width='10' type='ro' sort='str'>IP Address</column>
          <column width='10' type='ro' sort='str'>VMM Vendor</column>
          <column width='10' type='ro' sort='str'>VMM Version</column>
          <column width='10' type='ro' sort='str'>VMM Product</column>
          <column width='10' type='ro' sort='str'>Registered On</column>
          <column width='10' type='ro' sort='str'>SmartState Heartbeat</column>
          <column width='10' type='ro' sort='str'>SmartState Version</column>
          <column width='10' type='ro' sort='str'>WS Port</column>
          <settings>
            <colwidth>%</colwidth>
          </settings>
        </head>
        <row id='8'>
          <cell>esxdev001.localdomain^/host/show/8^_self</cell>
          <cell>esxdev001.localdomain</cell>
          <cell>192.168.177.49</cell>
          <cell>VMware</cell>
          <cell>3.0.2</cell>
          <cell>ESX Server</cell>
          <cell>Thu Jun 05 16:46:35 UTC 2008</cell>
          <cell></cell>
          <cell></cell>
          <cell></cell>
        </row>
        <row id='7'>
          <cell>esxdev002.localdomain^/host/show/7^_self</cell>
          <cell>esxdev002.localdomain</cell>
          <cell>192.168.177.50</cell>
          <cell>VMware</cell>
          <cell>3.0.2</cell>
          <cell>ESX Server</cell>
          <cell>Thu Jun 05 16:46:34 UTC 2008</cell>
          <cell></cell>
          <cell></cell>
          <cell></cell>
        </row>
        <row id='6'>
          <cell>JFREY-LAPTOP.manageiq.com^/host/show/6^_self</cell>
          <cell>JFREY-LAPTOP.manageiq.com</cell>
          <cell>192.168.252.143</cell>
          <cell>Unknown</cell>
          <cell></cell>
          <cell></cell>
          <cell>Wed Apr 23 19:38:44 UTC 2008</cell>
          <cell></cell>
          <cell></cell>
          <cell></cell>
        </row>
        <row id='4'>
          <cell>luke.manageiq.com^/host/show/4^_self</cell>
          <cell>luke.manageiq.com</cell>
          <cell>192.168.252.32</cell>
          <cell>VMware</cell>
          <cell>3.0.1</cell>
          <cell>ESX Server</cell>
          <cell>Tue Apr 22 15:59:19 UTC 2008</cell>
          <cell></cell>
          <cell></cell>
          <cell></cell>
        </row>
        <row id='5'>
          <cell>yoda.manageiq.com^/host/show/5^_self</cell>
          <cell>yoda.manageiq.com</cell>
          <cell>192.168.252.2</cell>
          <cell>VMware</cell>
          <cell>3.0.1</cell>
          <cell>ESX Server</cell>
          <cell>Tue Apr 22 15:59:20 UTC 2008</cell>
          <cell></cell>
          <cell></cell>
          <cell></cell>
        </row>
      </rows>
    EOL
    xml_string.strip!
  end

  def test_create_document
    xml = @xml
    assert_kind_of(@xml_klass::Document, xml)

    #    @xml_klass.load(@xml_string)
    #    assert_kind_of(@xml_klass::Document, xml)
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
    assert_equal("<?xml version='1.0' encoding='UTF-8'?>", xml_new.to_xml.to_s.gsub("\"", "'").chomp)
  end

  def test_xml_encoding()
    xml_new = @xml
    encoded_xml = xml_new.miqEncode()
    assert_instance_of(String, encoded_xml)
    xml_unencoded = MiqXml.decode(encoded_xml, @xml_klass)
    assert_equal(xml_new.to_s, xml_unencoded.to_s)
  end

  def test_find_each()
    xml = @xml
    row_order = %w{8 7 6 4 5}
    xml.find_each("//row") do |e|
      assert_equal(e.attributes["id"].to_s, row_order.delete_at(0))
    end
    assert_equal(0, row_order.length)
  end

  def test_find_first()
    xml = @xml
    x = xml.find_first("//row")
    assert_not_nil(x)
    assert_equal("8", x.attributes["id"].to_s)
  end

  def test_find_match()
    xml = @xml
    x = xml.find_match("//row")
    assert_not_nil(x)
    assert_equal(5, x.length)
    assert_equal("8", x[0].attributes["id"].to_s)
    assert_equal("4", x[3].attributes["id"].to_s)
  end

  def test_add_frozen_text()
    xml = @xml
    assert_kind_of(@xml_klass::Document, xml)

    frozen_text = "A&P".freeze
    # assert_nothing_raised {xml.root.text = frozen_text}
    #TODO: Fix decoding of special characters
    #assert_equal("A&P", xml.root.text)
  end

  def test_root_text
   node = @xml.root
    assert_equal("", node.node_text.to_s.rstrip)
    node.text = "Hello World"
    assert_equal("Hello World", node.node_text.to_s.rstrip)

    # Make sure adding text does not destroy child elements
    assert_equal(true, node.has_elements?)
    count = 0
    @xml.root.each_element {|e| count += 1}
    assert_equal(6, count)
  end

  def test_cdata()
    xml = MiqXml.newDoc(@xml_klass)
    xml.add_element('root')

    time = Time.now
		html_text = "<b>#{time}</b>"
    xml.root.add_cdata(html_text.gsub(",","\\,"))

    assert(xml.to_s.include?("![CDATA[<b>#{time}</b>]]"))
    assert_equal("<b>#{time}</b>", xml.root.text)
  end
end
