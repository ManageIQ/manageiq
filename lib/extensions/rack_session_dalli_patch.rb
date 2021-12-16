require "dalli"
require "rack/session/dalli"

module RackSessionDalliPatch
  def delete_sessions(session_ids)
    session_ids.each do |session_id|
      if Dalli::VERSION >= "3.1.0"
        delete_session(ManageIQ::Session.fake_request.env, session_id, :drop => true)
      else
        destroy_session(ManageIQ::Session.fake_request.env, session_id, :drop => true)
      end
    end
  end
end

begin
  if Dalli::VERSION >= "3.1.0"
    Rack::Session::Dalli.instance_method('delete_session')
  else
    Rack::Session::Dalli.instance_method('destroy_session')
  end
rescue NameError => err
  warn "Dalli #{Dalli::VERSION} is missing the method our prepended code depends on: #{err}."
  warn "Did the dalli version change?  Was the method removed or renamed upstream? See: #{__FILE__}"
end

Rack::Session::Dalli.prepend(RackSessionDalliPatch)
