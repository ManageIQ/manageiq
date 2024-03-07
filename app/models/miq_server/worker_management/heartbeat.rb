module MiqServer::WorkerManagement::Heartbeat
  extend ActiveSupport::Concern

  # Note, this entire file assumes the server process is running on the same filesystem as the workers
  # which isn't true in podified.  Therefore, we can't clean_heartbeat_files or get the workers_last_heartbeat
  # by reading the heartbeat_file.  Instead, we assume the liveness check is working and if it's still running
  # in podified, the row will exist and if so, we'll update the worker row with the current time.
  def persist_last_heartbeat(w)
    last_heartbeat = workers_last_heartbeat(w)

    if w.last_heartbeat.nil?
      last_heartbeat ||= Time.now.utc
      w.update(:last_heartbeat => last_heartbeat)
    elsif !last_heartbeat.nil? && last_heartbeat > w.last_heartbeat
      w.update(:last_heartbeat => last_heartbeat)
    end
  end

  def clean_heartbeat_files
    Dir.glob(Rails.root.join("tmp/*.hb")).each { |f| File.delete(f) }
  end

  private

  def workers_last_heartbeat(w)
    File.mtime(w.heartbeat_file).utc if File.exist?(w.heartbeat_file)
  end
end
