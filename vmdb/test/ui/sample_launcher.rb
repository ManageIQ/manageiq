#
# Sample test case launcher code...to be used with the testSuiteWrapper
# Require any test case files
# Set the attributes you want to pass along to the test methods in a array of
# hashes.  create a TestSuiteWrapper with the name of the test class and the
# attribute array.
#

$:.unshift File.join(File.dirname(__FILE__), "..")
require 'testSuiteWrapper'
require 'sample_tc'


attributes =[{"username"=>"admin","password"=>"smartvm"},
   {"username"=>"auditor","password"=>"auditor"},
   {"username"=>"test","password"=>"test"}
   ]

x = TestSuiteWrapper.new("SampleTc",attributes)
x.run
