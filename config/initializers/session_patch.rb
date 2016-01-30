class ActionDispatch::Request::Session
  include MoreCoreExtensions::Shared::Nested
end

class ActionController::TestSession < Rack::Session::Abstract::SessionHash
  include MoreCoreExtensions::Shared::Nested
end
