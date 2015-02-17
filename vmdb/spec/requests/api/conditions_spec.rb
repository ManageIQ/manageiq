#
# REST API Request Tests - Conditions
#
# Condition primary collection:
#   /api/conditions
#
# Condition subcollection:
#   /api/policies/:id/conditions
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

  def create_conditions(count)
    count.times { FactoryGirl.create(:condition) }
  end

  context "Condition collection" do
    it "query invalid collection" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_get "#{@cfme[:conditions_url]}/999999"

      expect(@code).to eq(404)
    end

    it "query conditions with no conditions defined" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_get @cfme[:conditions_url]

      expect(@code).to eq(200)
      expect(@result).to have_key("name")
      expect(@result["name"]).to eq("conditions")
      expect(@result["resources"].size).to eq(0)
    end

    it "query conditions" do
      basic_authorize @cfme[:user], @cfme[:password]

      create_conditions(3)
      @success = run_get @cfme[:conditions_url]

      expect(@code).to eq(200)
      expect(@result).to have_key("name")
      expect(@result["name"]).to eq("conditions")
      expect(@result["resources"].size).to eq(3)
      hrefs_ids = @result["resources"].collect { |r| r["href"].sub(/^.*#{@cfme[:conditions_url]}\//, '') }
      expect(hrefs_ids).to match_array(Condition.pluck(:id).collect(&:to_s))
    end

    it "query conditions in expanded form" do
      basic_authorize @cfme[:user], @cfme[:password]

      create_conditions(3)
      @success = run_get "#{@cfme[:conditions_url]}?expand=resources"

      expect(@code).to eq(200)
      expect(@result).to have_key("name")
      expect(@result["name"]).to eq("conditions")
      expect(@result["resources"].size).to eq(3)
      guids = @result["resources"].collect { |r| r["guid"] }
      expect(guids).to match_array(Condition.pluck(:guid))
    end
  end

  context "Condition subcollection" do
    before(:each) do
      @policy = FactoryGirl.create(:miq_policy, :name => "Policy 1")
      @policy_url = "#{@cfme[:policies_url]}/#{@policy.id}"
      @policy_conditions_url = "#{@policy_url}/conditions"
    end

    it "query conditions with no conditions defined" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_get @policy_conditions_url

      expect(@code).to eq(200)
      expect(@result).to have_key("name")
      expect(@result["name"]).to eq("conditions")
      expect(@result["resources"].size).to eq(0)
    end

    it "query conditions" do
      basic_authorize @cfme[:user], @cfme[:password]

      create_conditions(3)
      @policy.conditions = Condition.all

      @success = run_get "#{@policy_conditions_url}?expand=resources"

      expect(@code).to eq(200)
      expect(@result).to have_key("name")
      expect(@result["name"]).to eq("conditions")
      expect(@result["resources"].size).to eq(3)
      guids = @result["resources"].collect { |r| r["guid"] }
      expect(guids).to match_array(Condition.pluck(:guid))
    end

    it "query policy with expanded conditions" do
      basic_authorize @cfme[:user], @cfme[:password]

      create_conditions(3)
      @policy.conditions = Condition.all

      @success = run_get "#{@policy_url}?expand=conditions"

      expect(@code).to eq(200)
      expect(@result["name"]).to eq(@policy.name)
      expect(@result["description"]).to eq(@policy.description)
      expect(@result["guid"]).to eq(@policy.guid)
      expect(@result).to have_key("conditions")
      conditions = @result["conditions"]
      expect(conditions.size).to eq(3)
      guids = conditions.collect { |r| r["guid"] }
      expect(guids).to eq(Condition.pluck(:guid))
    end
  end
end
