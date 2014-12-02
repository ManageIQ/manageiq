#
# REST API Request Tests - /api versioning
#
require 'spec_helper'

describe ApiController do

  include Rack::Test::Methods

  before(:each) do
    init_api_spec_env
  end

  def app
    Vmdb::Application
  end

  context "Versioning Queries" do

    it "test versioning query" do
      basic_authorize @cfme[:user], @cfme[:password]
      @success = run_get @cfme[:entrypoint]
      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("versions")
    end

    it "test query with a valid version" do
      # Let's get the versions
      basic_authorize @cfme[:user], @cfme[:password]
      @success = run_get @cfme[:entrypoint]
      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("versions")
      expect(@result["versions"]).to_not be_nil
      # Let's get the first version
      expect(@result["versions"][0]).to_not be_nil
      ver = @result["versions"][0]
      expect(ver).to have_key("href")
      ident = ver["href"].split("/").last
      # Let's try to access that version API URL
      @success = run_get "#{@cfme[:entrypoint]}/#{ident}"
      expect(@success).to be_true
      expect(@code).to eq(200)
    end

    it "test query with an invalid version" do
      basic_authorize @cfme[:user], @cfme[:password]
      @success = run_get "#{@cfme[:entrypoint]}/v9999.9999"
      expect(@success).to be_false
      expect(@code).to eq(400)
    end

  end

end
