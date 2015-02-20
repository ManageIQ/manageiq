#
# REST API Request Tests - Events
#
# Event primary collection:
#   /api/events
#
# Event subcollection:
#   /api/policies/:id/events
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

  def create_events(count)
    count.times { FactoryGirl.create(:miq_event) }
  end

  context "Event collection" do
    it "query invalid event" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_get "#{@cfme[:events_url]}/999999"

      expect(@code).to eq(404)
    end

    it "query events with no events defined" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_get @cfme[:events_url]

      expect(@code).to eq(200)
      expect(@result).to have_key("name")
      expect(@result["name"]).to eq("events")
      expect(@result["resources"].size).to eq(0)
    end

    it "query events" do
      basic_authorize @cfme[:user], @cfme[:password]

      create_events(3)
      @success = run_get @cfme[:events_url]

      expect(@code).to eq(200)
      expect(@result).to have_key("name")
      expect(@result["name"]).to eq("events")
      expect(@result["resources"].size).to eq(3)
      hrefs_ids = @result["resources"].collect { |r| r["href"].sub(/^.*#{@cfme[:events_url]}\//, '') }
      expect(hrefs_ids).to match_array(MiqEvent.pluck(:id).collect(&:to_s))
    end

    it "query events in expanded form" do
      basic_authorize @cfme[:user], @cfme[:password]

      create_events(3)
      @success = run_get "#{@cfme[:events_url]}?expand=resources"

      expect(@code).to eq(200)
      expect(@result).to have_key("name")
      expect(@result["name"]).to eq("events")
      expect(@result["resources"].size).to eq(3)
      guids = @result["resources"].collect { |r| r["guid"] }
      expect(guids).to match_array(MiqEvent.pluck(:guid))
    end
  end

  context "Event subcollection" do
    before(:each) do
      @policy = FactoryGirl.create(:miq_policy, :name => "Policy 1")
      @policy_url = "#{@cfme[:policies_url]}/#{@policy.id}"
      @events_url = "#{@policy_url}/events"
    end

    it "query events with no events defined" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_get @events_url

      expect(@code).to eq(200)
      expect(@result).to have_key("name")
      expect(@result["name"]).to eq("events")
      expect(@result["resources"].size).to eq(0)
    end

    it "query events" do
      basic_authorize @cfme[:user], @cfme[:password]

      create_events(3)
      MiqEvent.all.collect(&:id).each do |event_id|
        MiqPolicyContent.create(:miq_policy_id => @policy.id, :miq_event_id => event_id)
      end

      @success = run_get "#{@events_url}?expand=resources"

      expect(@code).to eq(200)
      expect(@result).to have_key("name")
      expect(@result["name"]).to eq("events")
      expect(@result["resources"].size).to eq(3)
      guids = @result["resources"].collect { |r| r["guid"] }
      expect(guids).to match_array(MiqEvent.pluck(:guid))
    end

    it "query policy with expanded events" do
      basic_authorize @cfme[:user], @cfme[:password]

      create_events(3)
      MiqEvent.all.collect(&:id).each do |event_id|
        MiqPolicyContent.create(:miq_policy_id => @policy.id, :miq_event_id => event_id)
      end

      @success = run_get "#{@policy_url}?expand=events"

      expect(@code).to eq(200)
      expect(@result["name"]).to eq(@policy.name)
      expect(@result["description"]).to eq(@policy.description)
      expect(@result["guid"]).to eq(@policy.guid)
      expect(@result).to have_key("events")
      events = @result["events"]
      expect(events.size).to eq(3)
      guids = events.collect { |r| r["guid"] }
      expect(guids).to match_array(MiqEvent.pluck(:guid))
    end
  end
end
