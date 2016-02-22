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
  skip(@cfme[:client].message) if @cfme[:client].code == 0
end
