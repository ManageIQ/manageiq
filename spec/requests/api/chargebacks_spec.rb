require "spec_helper"

RSpec.describe "chargebacks API" do
  include Rack::Test::Methods

  def app
    Vmdb::Application
  end

  before { init_api_spec_env }

  it "can fetch the list of all chargeback rates" do
    chargeback_rate = FactoryGirl.create(:chargeback_rate)

    api_basic_authorize
    run_get "/api/chargebacks"

    json = JSON.parse(last_response.body)
    expect(json["count"]).to be 1
    expect(json["resources"].first["href"]).to end_with("/api/chargebacks/#{chargeback_rate.id}")
    expect(last_response.status).to eq(200)
  end

  it "can show an individual chargeback rate" do
    chargeback_rate = FactoryGirl.create(:chargeback_rate)

    api_basic_authorize
    run_get "/api/chargebacks/#{chargeback_rate.to_param}"

    json = JSON.parse(last_response.body)
    expect(json["description"]).to eq(chargeback_rate.description)
    expect(json["guid"]).to eq(chargeback_rate.guid)
    expect(json["id"]).to eq(chargeback_rate.id)
    expect(json["href"]).to end_with("/api/chargebacks/#{chargeback_rate.id}")
    expect(last_response.status).to eq(200)
  end

  it "can fetch chargeback rate details" do
    chargeback_rate_detail = FactoryGirl.create(:chargeback_rate_detail)
    chargeback_rate = FactoryGirl.create(:chargeback_rate,
                                         :chargeback_rate_details => [chargeback_rate_detail])

    api_basic_authorize
    run_get "/api/chargebacks/#{chargeback_rate.to_param}/rates"

    json = JSON.parse(last_response.body)
    expect(json["count"]).to be 1
    expect(json["subcount"]).to be 1
    expect(json["name"]).to eq("rates")
    expect(json["resources"].first["href"]).to end_with("/api/chargebacks/#{chargeback_rate.to_param}/rates/#{chargeback_rate_detail.to_param}")
    expect(last_response.status).to eq(200)
  end

  it "can fetch an individual chargeback rate detail" do
    chargeback_rate_detail = FactoryGirl.create(:chargeback_rate_detail, :rate => 5)
    chargeback_rate = FactoryGirl.create(:chargeback_rate,
                                         :chargeback_rate_details => [chargeback_rate_detail])

    api_basic_authorize
    run_get "/api/chargebacks/#{chargeback_rate.to_param}/rates/#{chargeback_rate_detail.to_param}"

    json = JSON.parse(last_response.body)
    expect(json["chargeback_rate_id"]).to eq(chargeback_rate.id)
    expect(json["href"]).to end_with("/api/chargebacks/#{chargeback_rate.to_param}/rates/#{chargeback_rate_detail.to_param}")
    expect(json["id"]).to eq(chargeback_rate_detail.id)
    expect(json["rate"]).to eq("5")
    expect(last_response.status).to eq(200)
  end
end
