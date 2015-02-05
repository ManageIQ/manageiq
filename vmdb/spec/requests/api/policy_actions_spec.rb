#
# REST API Request Tests - Policy Actions
#
# Policy Action primary collection:
#   /api/policy_actions
#
# Policy Action subcollection:
#   /api/policies/:id/policy_actions
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

  def create_actions(count)
    1.upto(count) do |i|
      FactoryGirl.create(:miq_action, :name => "custom_action_#{i}", :description => "Custom Action #{i}")
    end
  end

  context "Policy Action collection" do
    it "query invalid action" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_get "#{@cfme[:policy_actions_url]}/999999"

      expect(@code).to eq(404)
    end

    it "query policy actions with no actions defined" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_get @cfme[:policy_actions_url]

      expect(@code).to eq(200)
      expect(@result).to have_key("name")
      expect(@result["name"]).to eq("policy_actions")
      expect(@result["resources"].size).to eq(0)
    end

    it "query policy actions" do
      basic_authorize @cfme[:user], @cfme[:password]

      create_actions(10)
      @success = run_get @cfme[:policy_actions_url]

      expect(@code).to eq(200)
      expect(@result).to have_key("name")
      expect(@result["name"]).to eq("policy_actions")
      expect(@result["resources"].size).to eq(10)
      hrefs_ids = @result["resources"].collect { |r| r["href"].sub(/^.*#{@cfme[:policy_actions_url]}\//, '') }
      expect(hrefs_ids.sort).to eq(MiqAction.all.collect(&:id).collect(&:to_s).sort)
    end

    it "query policy actions in expanded form" do
      basic_authorize @cfme[:user], @cfme[:password]

      create_actions(10)
      @success = run_get "#{@cfme[:policy_actions_url]}?expand=resources"

      expect(@code).to eq(200)
      expect(@result).to have_key("name")
      expect(@result["name"]).to eq("policy_actions")
      expect(@result["resources"].size).to eq(10)
      guids = @result["resources"].collect { |r| r["guid"] }
      expect(guids.sort).to eq(MiqAction.all.collect(&:guid).sort)
    end
  end

  context "Policy Action subcollection" do
    before(:each) do
      @policy = FactoryGirl.create(:miq_policy, :name => "Policy 1")
      @policy_url = "#{@cfme[:policies_url]}/#{@policy.id}"
      @policy_actions_url = "#{@policy_url}/policy_actions"
    end

    it "query policy actions with no actions defined" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_get @policy_actions_url

      expect(@code).to eq(200)
      expect(@result).to have_key("name")
      expect(@result["name"]).to eq("policy_actions")
      expect(@result["resources"].size).to eq(0)
    end

    it "query policy actions" do
      basic_authorize @cfme[:user], @cfme[:password]

      create_actions(4)
      MiqAction.all.collect(&:id).each do |action_id|
        MiqPolicyContent.create(:miq_policy_id => @policy.id, :miq_action_id => action_id)
      end

      @success = run_get "#{@policy_actions_url}?expand=resources"

      expect(@code).to eq(200)
      expect(@result).to have_key("name")
      expect(@result["name"]).to eq("policy_actions")
      expect(@result["resources"].size).to eq(4)
      guids = @result["resources"].collect { |r| r["guid"] }
      expect(guids.sort).to eq(MiqAction.all.collect(&:guid).sort)
    end

    it "query policy with expanded policy actions" do
      basic_authorize @cfme[:user], @cfme[:password]

      create_actions(4)
      MiqAction.all.collect(&:id).each do |action_id|
        MiqPolicyContent.create(:miq_policy_id => @policy.id, :miq_action_id => action_id)
      end

      @success = run_get "#{@policy_url}?expand=policy_actions"

      expect(@code).to eq(200)
      expect(@result["name"]).to eq(@policy.name)
      expect(@result["description"]).to eq(@policy.description)
      expect(@result["guid"]).to eq(@policy.guid)
      expect(@result).to have_key("policy_actions")
      policy_actions = @result["policy_actions"]
      expect(policy_actions.size).to eq(4)
      guids = policy_actions.collect { |r| r["guid"] }
      expect(guids.sort).to eq(MiqAction.all.collect(&:guid).sort)
    end
  end
end
