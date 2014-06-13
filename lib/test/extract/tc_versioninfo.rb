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
    get_versioninfo(File.join(@dataPath, "VMwareTray.exe")) # This is the VMware tray module from VM Server
    get_versioninfo(File.join(@dataPath, "frhed.exe"))       # This is the Free Hex Editor module
  end

  def get_versioninfo(filename)
    vi = File.getVersionInfo(filename)
    
    # Validate that we get a Hash back
    assert_instance_of(Hash, vi)
    
    # Validate the basic fields are not nil
    assert_not_nil(vi['sig'])
    assert_not_nil(vi['PRODUCTVERSION_HEADER'])
    assert_not_nil(vi['FILEVERSION_HEADER'])
    assert_not_nil(vi['code_page'])
    assert_not_nil(vi['lang'])
    assert_not_nil(vi['data_length'])
    assert_equal("StringFileInfo", vi['sig'])

    # Validate that the string data is within a range.  (400-1000 chars)
    assert_in_delta(700, vi['data_length'], 300)

    # Validate that the external name matches the internal name
    assert_equal(File.basename(filename), vi['OriginalFilename'])

    # Check that we can sort the hash into an array
    sortedArray = vi.sort {|a,b| a<=>b}
    assert_instance_of(Array, sortedArray)
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