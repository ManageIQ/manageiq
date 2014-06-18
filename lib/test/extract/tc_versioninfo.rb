$:.push("#{File.dirname(__FILE__)}/../../metadata/util/win32")
require 'versioninfo'
require 'test/unit'

module Extract
	
class TestVersionInfo < Test::Unit::TestCase
  def setup
    @dataPath = File.join(File.dirname(File.expand_path(__FILE__)), "data")
    @noFile   = File.expand_path(File.join(@dataPath, "nofile.txt"))
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
