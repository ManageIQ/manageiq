RSpec.describe "Normalization of objects API" do
  it "represents datetimes in ISO8601 format" do
    api_basic_authorize "host_show"
    host = FactoryGirl.create(:host)

    run_get(hosts_url(host.id))

    expect(response.parsed_body).to include("created_on" => host.created_on.iso8601)
  end
end
