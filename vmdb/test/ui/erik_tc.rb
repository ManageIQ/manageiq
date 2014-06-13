#
# Sample test case to be used with the testSuiteWrapper
#
# In the normal test/unit test case, you can access the dynamic values like this:
# hAttributes["username"]
# hAttributes["password"]
#


require 'test/unit'


class SampleTc < ActiveSupport::TestCase


  def test_username
    puts "\nusername= #{hAttributes["username"]}"
#    flunk "@username = #{hAttributes["username"]}"
  end
  def test_password
    puts "\npassword= #{hAttributes["password"]}"
#    flunk "@password = #{hAttributes["password"]}"
  end
  def test_hash
    puts hAttributes.inspect
  end
  def test_valid
    puts "\nvalidity = #{hAttributes["valid"]}"
    if (hAttributes["valid"] == "1")
      flunk "@username #{hAttributes["username"]}/@password #{hAttributes["password"]} not valid"
    end
  end
  def test_servicelevel
    assert_nil hAttributes["servicelevel"]
  end
end




