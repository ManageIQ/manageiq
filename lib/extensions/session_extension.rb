class ActionDispatch::Request::Session
  include MoreCoreExtensions::Shared::Nested
end

class ActionController::TestSession < Rack::Session::Abstract::PersistedSecure::SecureSessionHash
  include MoreCoreExtensions::Shared::Nested
end
