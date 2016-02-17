RSpec.shared_context "api request specs", :type => :request do
  include Rack::Test::Methods
  before { init_api_spec_env }
  def app
    Vmdb::Application
  end
end
