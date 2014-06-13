$:.push("#{File.dirname(__FILE__)}/../../util/")
require 'miq-xml'
require 'test/unit'

class TestBaseXmlMethods < Test::Unit::TestCase
	def setup
	end
	
	def teardown
	end
	
	def test_htmlEncoding()
		xmlType = REXML
		test_string = "This ain't no way to do it & we don't know how"
		encoded_string = "This ain&apos;t no way to do it &amp; we don&apos;t know how"
		test_int = 200

		# Create an XML document
		xml = MiqXml.load("<test/>", xmlType)
		assert_instance_of(REXML::Document, xml)

		# Load up all the data.  (Create a new elemenat with an attribute and text)
		xml.root.add_element("test_element", {"test_attr_str"=>test_string, "test_attr_int"=>test_int}).text = test_string
		check_element(xml.root.elements[1], test_string, encoded_string)

		# Make sure we were able to set an integer and get it back
		# Everything in xml is a string, so test base value and converted to_i value.
		assert_equal(xml.root.elements[1].attributes["test_attr_int"], test_int.to_s)
		assert_equal(xml.root.elements[1].attributes["test_attr_int"].to_i, test_int)
		
		# This is where the enocoding was messed up.  If we write the data out (to a string or file)
		# it would not encode the attributes and the encoded elements would get doubled up
		# when asking for the attribute back.
		1.upto(5) do |i|
			data = ""
			xml.write(data,0)
			xml = MiqXml.load(data, xmlType)
			assert_instance_of(REXML::Document, xml)
			check_element(xml.root.elements[1], test_string, encoded_string)
		end
	end
	
	def check_element(e, value, encoded_value)
		assert_equal(e.attributes["test_attr_str"], value)
		x = e.attributes.get_attribute("test_attr_str")
		assert_equal(x.to_s, encoded_value)
		assert_equal(x.value, value)
  end
end
