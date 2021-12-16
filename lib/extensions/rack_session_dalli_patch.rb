require "dalli"
require "rack/session/dalli"

module RackSessionDalliPatch
  def delete_sessions(session_ids)
    session_ids.each do |session_id|
      delete_session(ManageIQ::Session.fake_request.env, session_id, :drop => true)
    end
  end
end

begin
  Rack::Session::Dalli.instance_method('delete_session')
rescue NameError => err
  warn "Dalli #{Dalli::VERSION} is missing the method our prepended code depends on: #{err}."
  warn "Did the dalli version change?  Was the method removed or renamed upstream? See: #{__FILE__}"
end

Rack::Session::Dalli.prepend(RackSessionDalliPatch)
