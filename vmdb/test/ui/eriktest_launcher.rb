#
# Sample test case launcher code...to be used with the testSuiteWrapper
# Require any test case files
# Set the attributes you want to pass along to the test methods in a array of
# hashes.  create a TestSuiteWrapper with the name of the test class and the
# attribute array.
#

$:.unshift File.join(File.dirname(__FILE__), "..")
require 'testSuiteWrapper'
require 'erik_tc'
require 'userlogin_tc'


attributes =[{"username"=>"admin","password"=>"smartvm", "valid"=>"0"},
   {"username"=>"ErikAuditor","password"=>"test", "valid"=>"0"},
   {"username"=>"ErikAdministrator","password"=>"test", "valid"=>"0"},
   {"username"=>"ErikApprover","password"=>"test", "valid"=>"0"},
   {"username"=>"ErikOperator","password"=>"test", "valid"=>"0"},
   {"username"=>"ErikSecurity","password"=>"test", "valid"=>"0"},
   {"username"=>"ErikSupport","password"=>"test", "valid"=>"0"},
   {"username"=>"ErikUser","password"=>"test", "valid"=>"0"},
   {"username"=>"Erik","password"=>"fun", "valid"=>"0"},
   {"username"=>"ErikUser","password"=>"test2", "valid"=>"1"},
   {"username"=>"ErikUser","password"=>"test3", "valid"=>"1"},
   {"username"=>"ErikUser","password"=>"test4", "valid"=>"1"},
   {"username"=>"ErikUser","password"=>"test5", "valid"=>"1"},
   {"username"=>"ErikGold","password"=>"gold", "valid"=>"0", "servicelevel"=>"Gold"}
   ]

#x = TestSuiteWrapper.new("SampleTc",attributes)
#x.run
x = TestSuiteWrapper.new("LoginTest",attributes)
x.run
