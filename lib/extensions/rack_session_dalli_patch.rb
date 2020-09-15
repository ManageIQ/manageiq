require "dalli"
require "rack/session/dalli"

module RackSessionDalliPatch
  def delete_sessions(session_ids)
    session_ids.each do |session_id|
      delete_session(ManageIQ::Session.fake_request, session_id, :drop => true)
    end
  end

  # As we monkey-patch marshal to support autoloading, Dalli can
  # cause a load to occur. Consequently, we need to manage things
  # carefully to prevent a deadlock between the Rails Interlock and
  # Dalli's own exclusive lock.
  def with_lock(*args)
    ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
      super(*args) do
        ActiveSupport::Dependencies.interlock.running do
          yield
        end
      end
    end
  end
end

Rack::Session::Dalli.prepend(RackSessionDalliPatch)
