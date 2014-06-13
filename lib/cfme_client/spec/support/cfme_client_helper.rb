#
# Helper procs for the CfmeClient tests
#

require 'cfme_client'

#
# Initialize CfmeClient API
#
def init_api
  @cfme = {
    :client     => CfmeClient.new(:url => "http://localhost:3000"),
    :user       => "admin",
    :password   => "smartvm",
    :auth_token => ""
  }
end

#
# Check the CfmeClient API only if we successfuly connected to the REST API.
#
def test_api?
  if @cfme[:client].code == 0
    puts "#{@cfme[:client].message} - Skipping"
    return false
  end
  true
end
