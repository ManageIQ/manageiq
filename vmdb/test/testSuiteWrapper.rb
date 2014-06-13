# testSuiteWrapper class:
#
# Code that extends the test unit TestCase class and provides the ability to run
# a set of test methods once for each set of input parameters as separate tests
# that are wrapped in a TestSuite.  For example, if you have 3 test methods that
# test authentication and 10 possible sets of credentials that you would like to
# provide to each of these test methods, this new code will create 30 separate
# test cases (the 3 test methods are duplicated 10 times each) with 1 set of
# credentials provided in a instance variable of each test case class.
#
# Requires:
# 1) A launcher file that gathers all test cases and provides them the needed
#   dynamic data, etc.
# 2) This testSuiteWrapper file
# 3) A normal test/unit test case file
#
#See ui/sample_launcher
#See ui/sample_tc
#





$:.unshift File.join(File.dirname(__FILE__))

## Need access to the test unit test suite class in order to create new suites
## need to manually run the suite so need testrunner
require 'test/unit/testsuite'
require 'test/unit/ui/console/testrunner'


# extended the TestCase class in order to provide access to a hashed attribute
# this attribute contains the dynamic data needed for the current test case
# ie, if your test case authenticates using a username and password, this attribute
# will be populated with a single set of credentials for each test case
class Test::Unit::TestCase
  attr_accessor :hAttributes

end

class TestSuiteWrapper
  # array of hashes to store the username/password combos

  def initialize(tc, attrs)
    # need to store the test class's name so we can dynamically instantiate it later
    # each hash within attrs is passed along and stored in the individual test case
    @tcName = tc
    @arrAttributes = attrs
  end

  # Run the current instance of the TestSuiteWrapper
  def run
    Test::Unit::UI::Console::TestRunner.run(self.suite)
  end

  # umbrella suite that collects all of the sub-suites and test cases within
  # these sub-suites.  all tests are run from this test suite.
  def suite
    suite = Test::Unit::TestSuite.new("#{@tcName}")
    suite << createSuiteOfSuites
    return suite
  end

  private
  # creates a new suite which will contain all of the suites of individual
  # tests for each attribute set in the array of hashes
  def createSuiteOfSuites
    suiteOfSuite = Test::Unit::TestSuite.new("suite of suites")
    @arrAttributes.each do |attrHash|
      suiteOfSuite << createSuiteOfTests(attrHash)
    end
    return suiteOfSuite
  end

  # here is where the methods of the test case class are copied into new test
  # cases for each set of attributes.  These attributes are passed along in
  # the hAttributes of the instance of the test case class.  All of the tests
  # are wrapped in a suite and returned.
  def createSuiteOfTests(attrHash)
    suite = Test::Unit::TestSuite.new("suite of tests")
    # in order to access the test class, we eval the "string" provided at ".new"
    # time.  Ie, if the string was "MyTestCase",  want this to be a class and
    # not a string.  Hence, the eval.
    testClass = eval(@tcName)
    testClass.suite().tests.each do |t|
      tc = testClass.new(t.method_name)
      tc.hAttributes = attrHash
      suite << tc
    end
    return suite
  end
end

