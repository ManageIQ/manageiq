# encoding: UTF-8

require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. .. util})))
require 'miq-xml'

describe MIQRexml do
  it "attribute encoding" do
    xml = REXML::Document.new("<test/>")
    copyright_char = "\xC2\xAE"
    attr_string = "string #{copyright_char}"
    xml.root.add_element("element_1", {'attr1' => attr_string})
    xml.root.elements[1].attributes['attr1'].should == attr_string
  end

  it "load document encoding" do
    copyright_char = "\xC2\xAE"
    attr_string = "string #{copyright_char}"
    doc_text = "<test><element_1 attr1='#{attr_string}'/></test>"
    xml = MiqXml.load(doc_text)
    xml.root.elements[1].attributes['attr1'].should == attr_string
  end

  it "load document with UTF-8 BOM" do
    attr_string = "test string"
    utf8_bom = "\xC3\xAF\xC2\xBB\xC2\xBF"
    doc_text = "#{utf8_bom}<test><element_1 attr1='#{attr_string}'/></test>"

    xml = MiqXml.load(doc_text)
    xml.root.elements[1].attributes['attr1'].should == attr_string
  end
end
