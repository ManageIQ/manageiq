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

    expect_result_resources_to_include_data(
      "resources",
      "href" => [
        "http://example.org/api/chargebacks/#{chargeback_rate.to_param}"
      ]
    )
    expect_result_to_match_hash(@result, "count" => 1)
    expect_request_success
  end

  it "can show an individual chargeback rate" do
    chargeback_rate = FactoryGirl.create(:chargeback_rate)

    api_basic_authorize
    run_get "/api/chargebacks/#{chargeback_rate.to_param}"

    expect_result_to_match_hash(
      @result,
      "description" => chargeback_rate.description,
      "guid"        => chargeback_rate.guid,
      "id"          => chargeback_rate.id,
      "href"        => "http://example.org/api/chargebacks/#{chargeback_rate.to_param}"
    )
    expect_request_success
  end

  it "can fetch chargeback rate details" do
    chargeback_rate_detail = FactoryGirl.create(:chargeback_rate_detail)
    chargeback_rate = FactoryGirl.create(:chargeback_rate,
                                         :chargeback_rate_details => [chargeback_rate_detail])

    api_basic_authorize
    run_get "/api/chargebacks/#{chargeback_rate.to_param}/rates"

    expect_result_to_match_hash(
      @result,
      "count"    => 1,
      "subcount" => 1,
      "name"     => "rates"
    )

    expect_result_resources_to_include_data(
      "resources",
      "href" => [
        "http://example.org/api/chargebacks/#{chargeback_rate.to_param}/rates/#{chargeback_rate_detail.to_param}"
      ]
    )
    expect_request_success
  end

  it "can fetch an individual chargeback rate detail" do
    chargeback_rate_detail = FactoryGirl.create(:chargeback_rate_detail, :rate => 5)
    chargeback_rate = FactoryGirl.create(:chargeback_rate,
                                         :chargeback_rate_details => [chargeback_rate_detail])

    api_basic_authorize
    run_get "/api/chargebacks/#{chargeback_rate.to_param}/rates/#{chargeback_rate_detail.to_param}"

    expect_result_to_match_hash(
      @result,
      "chargeback_rate_id" => chargeback_rate.id,
      "href"               => "/api/chargebacks/#{chargeback_rate.to_param}/rates/#{chargeback_rate_detail.to_param}",
      "id"                 => chargeback_rate_detail.id,
      "rate"               => "5"
    )
    expect_request_success
  end
end
