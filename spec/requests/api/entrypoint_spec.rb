RSpec.describe "API entrypoint" do
  it "returns a :settings hash" do
    api_basic_authorize

    run_get entrypoint_url

    expect_single_resource_query
    expect_result_to_have_keys(%w(settings))
    expect(response_hash['settings']).to be_kind_of(Hash)
  end

  it "returns a locale" do
    api_basic_authorize

    run_get entrypoint_url

    expect(%w(en en_US)).to include(response_hash['settings']['locale'])
  end
end
