$:.push("#{File.dirname(__FILE__)}")
$:.push("#{File.dirname(__FILE__)}/../../util/")
require 'rubygems'
require 'minitest/unit'
require 'miq-xml'


class TestBaseXmlMethods < Minitest::Test
  require 'xml_base_parser_tests'
  include XmlBaseParserTests

	def setup
    @xml_klass = REXML
    @xml_string = self.default_test_xml() if @xml_string.nil?
    @xml = MiqXml.load(@xml_string, @xml_klass)
	end

	def teardown
	end
end
