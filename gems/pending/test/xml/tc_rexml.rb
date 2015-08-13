require 'minitest/unit'
require 'util/miq-xml'

class TestBaseXmlMethods < Minitest::Test
  require_relative 'xml_base_parser_tests'
  include XmlBaseParserTests

	def setup
    @xml_klass = REXML
    @xml_string = self.default_test_xml() if @xml_string.nil?
    @xml = MiqXml.load(@xml_string, @xml_klass)
	end

	def teardown
	end
end
