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
    1.upto(count) do |i|
      FactoryGirl.create(:condition, :name => "condition_#{i}", :description => "Condition #{i}")
    end
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

      create_conditions(10)
      @success = run_get @cfme[:conditions_url]

      expect(@code).to eq(200)
      expect(@result).to have_key("name")
      expect(@result["name"]).to eq("conditions")
      expect(@result["resources"].size).to eq(10)
      hrefs_ids = @result["resources"].collect { |r| r["href"].sub(/^.*#{@cfme[:conditions_url]}\//, '') }
      expect(hrefs_ids.sort).to eq(Condition.all.collect(&:id).collect(&:to_s).sort)
    end

    it "query conditions in expanded form" do
      basic_authorize @cfme[:user], @cfme[:password]

      create_conditions(10)
      @success = run_get "#{@cfme[:conditions_url]}?expand=resources"

      expect(@code).to eq(200)
      expect(@result).to have_key("name")
      expect(@result["name"]).to eq("conditions")
      expect(@result["resources"].size).to eq(10)
      guids = @result["resources"].collect { |r| r["guid"] }
      expect(guids.sort).to eq(Condition.all.collect(&:guid).sort)
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

      create_conditions(4)
      @policy.conditions = Condition.all

      @success = run_get "#{@policy_conditions_url}?expand=resources"

      expect(@code).to eq(200)
      expect(@result).to have_key("name")
      expect(@result["name"]).to eq("conditions")
      expect(@result["resources"].size).to eq(4)
      guids = @result["resources"].collect { |r| r["guid"] }
      expect(guids.sort).to eq(Condition.all.collect(&:guid).sort)
    end

    it "query policy with expanded conditions" do
      basic_authorize @cfme[:user], @cfme[:password]

      create_conditions(4)
      @policy.conditions = Condition.all

      @success = run_get "#{@policy_url}?expand=conditions"

      expect(@code).to eq(200)
      expect(@result["name"]).to eq(@policy.name)
      expect(@result["description"]).to eq(@policy.description)
      expect(@result["guid"]).to eq(@policy.guid)
      expect(@result).to have_key("conditions")
      conditions = @result["conditions"]
      expect(conditions.size).to eq(4)
      guids = conditions.collect { |r| r["guid"] }
      expect(guids.sort).to eq(Condition.all.collect(&:guid).sort)
    end
  end
end
