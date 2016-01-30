RSpec.describe "API entrypoint" do
  include Rack::Test::Methods

  before(:each) do
    init_api_spec_env
  end

  def app
    Vmdb::Application
  end

  it "returns a :settings hash" do
    api_basic_authorize

    run_get entrypoint_url

    expect_single_resource_query
    expect_result_to_have_keys(%w(settings))
    expect(@result['settings']).to be_kind_of(Hash)
  end

  it "returns a locale" do
    api_basic_authorize

    run_get entrypoint_url

    expect(%w(en en_US)).to include(@result['settings']['locale'])
  end
end
