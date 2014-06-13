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
end




