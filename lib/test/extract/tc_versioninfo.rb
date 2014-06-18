$:.push("#{File.dirname(__FILE__)}/../../metadata/util/win32")
require 'versioninfo'
require 'test/unit'

module Extract
	
class TestVersionInfo < Test::Unit::TestCase
  def setup
    @dataPath = File.join(File.dirname(File.expand_path(__FILE__)), "data")
    @noFile   = File.expand_path(File.join(@dataPath, "nofile.txt"))
  end

  def test_exes
    get_versioninfo(File.join(@dataPath, "pe_header_version_info_test.exe"))
  end

  def get_versioninfo(filename)
    vi = File.getVersionInfo(filename)
    
    # Validate that we get a Hash back
    assert_instance_of(Hash, vi)
    
    # Validate the basic fields are not nil
    assert_equal("StringFileInfo", vi['sig'])
    assert_equal('5,6,7,8',        vi['PRODUCTVERSION_HEADER'])
    assert_equal('5,6,7,8',        vi['FILEVERSION_HEADER'])
    assert_equal('04b0',           vi['code_page'])
    assert_equal('0000',           vi['lang'])
    assert_equal(896,              vi['data_length'])

    # Validate that the external name matches the internal name
    assert_equal(File.basename(filename), vi['OriginalFilename'])
  end
  
  def test_textFile
    assert_raise(RuntimeError) {File.getVersionInfo(__FILE__)}  # Test this ruby source file, which does not have version info
  end
  
  def test_no_file
    begin
      File.delete(@noFile)
    rescue Errno::ENOENT
    end
    assert_raise(Errno::ENOENT) {File.getVersionInfo(@noFile)}  # This file should not exist

    f = File.new(@noFile,"w+")
    assert_raise(RuntimeError) {File.getVersionInfo(@noFile)}  # This file should now exist, but be zero bytes
    f.close
    File.delete(@noFile)
  end
end

end
