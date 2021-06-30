require "dalli"
require "rack/session/dalli"

module RackSessionDalliPatch
  def delete_sessions(session_ids)
    session_ids.each do |session_id|
      destroy_session(ManageIQ::Session.fake_request, session_id, :drop => true)
    end
  end

  # As we monkey-patch marshal to support autoloading, Dalli can
  # cause a load to occur. Consequently, we need to manage things
  # carefully to prevent a deadlock between the Rails Interlock and
  # Dalli's own exclusive lock.
  def with_block(*args)
    ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
      super do |dc|
        ActiveSupport::Dependencies.interlock.running do
          yield dc
        end
      end
    end
  end
end

# In commit: https://github.com/petergoldstein/dalli/commit/9f9c508afab263a2451f2209c4396daf98d33a1b
# with_lock was renamed to with_block with a slightly different interface.
# All versions since 2.7.7 have with_block now.
# Additionally, we'll detect and warn if the method we depend on in our prepended module doesn't exist before we try to prepend it.
%w[with_block destroy_session].each do |method|
  begin
    Rack::Session::Dalli.instance_method(method)
  rescue NameError => err
    warn "Dalli is missing the method our prepended code depends on: #{err}."
    warn "Did the dalli version change?  Was the method removed or renamed upstream? See: #{__FILE__}"
  end
end
Rack::Session::Dalli.prepend(RackSessionDalliPatch)
