$:.push("#{File.dirname(__FILE__)}/../../metadata/util/")
require 'md5deep'
require 'test/unit'

module Extract
	
class TestVersionInfo < Test::Unit::TestCase

  def test_md5deep
    md5 = MD5deep.new
    xml = md5.scan(File.dirname(__FILE__))

    # Validate that we get a XML Document back
    assert_instance_of(XmlHash::Document, xml)

    # root Node is namged md5deep
    assert_equal(:filesystem, xml.root.name)
    
    # The first element should be a directory based on the starting point.
    assert_equal(:dir, xml.root.elements[1].name)
    
    # Base element should have a valid MD5 sig.
    assert_not_nil(xml.root.elements[1].attributes['md5'])

    # MD5 sig should be 32 bits in length
    assert_in_delta(32, xml.root.elements[1].attributes['md5'].strip.length, 0)

    # Base element should have the default name value
    assert_equal("/", xml.root.elements[1].attributes['name'])
  end
end

end