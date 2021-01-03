module ActiveRecordSessionStorePatch
  def delete_sessions(session_ids)
    session_ids.each do |session_id|
      delete_session(ManageIQ::Session.fake_request, session_id, :drop => true)
    end
  end
end

ActionDispatch::Session::ActiveRecordStore.prepend(ActiveRecordSessionStorePatch)
