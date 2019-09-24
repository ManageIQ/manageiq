class Session < ApplicationRecord
  @@timeout = 3600 # session time to live in seconds
  @@interval = 30 # how often to purge in seconds
  @@job ||= nil

  def self.enabled?
    ::Settings.server.session_store == 'sql'
  end

  def self.check_session_timeout
    $log.debug("Checking session data")
    purge(::Settings.session.timeout)
  end

  def self.purge(ttl, batch_size = 100)
    deleted = 0
    loop do
      cnt = purge_one_batch(ttl, batch_size)
      deleted += cnt

      break if cnt.zero?
    end

    _log.info("purged stale session data, #{deleted} entries deleted") unless deleted == 0
  end

  def self.purge_one_batch(ttl, batch_size)
    sessions = where("updated_at <= ?", ttl.seconds.ago.utc).limit(batch_size)
    return 0 if sessions.size.zero?
    sessions = sessions.reject do |s|
      expires_on = s.raw_data[:expires_on] rescue nil
      expires_on && expires_on >= Time.zone.now
    end

    log_off_user_sessions(sessions)
    where(:id => sessions.collect(&:id)).destroy_all.size
  end

  def self.log_off_user_sessions(sessions)
    # Log off the users associated with the sessions that are eligible for deletion
    userids = sessions.each_with_object([]) do |s, a|
      begin
        a << s.raw_data[:userid]
      rescue => err
        _log.warn("Error '#{err.message}', attempting to load session with id [#{s.id}]")
      end
    end

    User.where(:userid => userids).each do |user|
      if (user.lastlogoff && user.lastlogon && user.lastlogoff < user.lastlogon) || (user.lastlogon && user.lastlogoff.nil?)
        user.logoff
      end
    end
  end

  def self.timeout(ttl = nil)
    @@timeout = ttl unless ttl.nil?
    @@timeout
  end

  def self.interval(int = nil)
    @@interval = int unless int.nil?
    @@interval
  end

  def raw_data
    Marshal.load(Base64.decode64(data.split("\n").join))
  end

  def raw_data=(d)
    self.data = Base64.encode64(Marshal.dump(d))
  end
end
