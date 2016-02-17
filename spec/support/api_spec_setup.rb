RSpec.shared_context "api request specs", :rest_api => true do
  include Rack::Test::Methods
  before { init_api_spec_env }
  def app
    Vmdb::Application
  end
end
