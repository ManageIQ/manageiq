#
# Tests to exercise the CfmeClient
#
# Requires EVM to be running
#
# Run as rspec spec
#

require 'spec_helper'

describe "CfmeClient Versioning" do

  before do
    @cfme = init_api
  end

  context "Versioning Queries" do

    it "test versioning query" do
      success = @cfme[:client].entrypoint(:user => @cfme[:user], :password => @cfme[:password])
      if test_api?
        expect(success).to be_true
        expect(@cfme[:client].code).to eq(200)
        expect(@cfme[:client].result).to have_key("versions")
        @cfme[:versions] = @cfme[:client].result["versions"]
        @cfme[:versions][0].should_not be_nil
        expect(@cfme[:versions][0]).to have_key("name")
      end
    end

    it "test query with a valid version" do
      success = @cfme[:client].entrypoint(:user => @cfme[:user], :password => @cfme[:password])
      if test_api?
        expect(success).to be_true
        expect(@cfme[:client].code).to eq(200)
        expect(@cfme[:client].result).to have_key("versions")
        @cfme[:versions] = @cfme[:client].result["versions"]
        @cfme[:versions][0].should_not be_nil
        expect(@cfme[:versions][0]).to have_key("name")
        success = @cfme[:client].entrypoint(:version => @cfme[:versions][0]["name"])
        expect(success).to be_true
        expect(@cfme[:client].code).to eq(200)
      end
    end

    it "test query with an invalid version" do
      success = @cfme[:client].entrypoint(:user => @cfme[:user], :password => @cfme[:password], :version => "9999.9999")
      if test_api?
        expect(success).to be_false
        expect(@cfme[:client].code).to eq(400)
      end
    end

  end

end
