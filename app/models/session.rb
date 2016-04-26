class Session < ApplicationRecord
  @@timeout = 3600 # session time to live in seconds
  @@interval = 30 # how often to purge in seconds
  @@job ||= nil

  def self.check_session_timeout
    $log.debug "Checking session data"
    ttl = timeout
    cfg = VMDB::Config.new("vmdb").config[:session]
    ttl = cfg[:timeout] if cfg[:timeout].to_int != ttl
    purge(ttl)
  end

  def self.purge(ttl, batch_size = 100)
    deleted = 0
    loop do
      sessions = where("updated_at <= ?", ttl.seconds.ago.utc).limit(batch_size)
      break if sessions.size.zero?

      # Log off the users associated with the sessions that are eligible for deletion
      begin
        userids = sessions.each_with_object([]) {|s, a|
          a << Marshal.load(Base64.decode64(s.data.split("\n").join))[:userid]
        }

        User.where(:userid => userids).each do |user|
          if user && ((user.lastlogoff && user.lastlogon && user.lastlogoff < user.lastlogon) || (user.lastlogon && user.lastlogoff.nil?))
            user.logoff
          end
        end
      rescue => err
        _log.warn("Error '#{err.message}', attempting to delete session with id [#{sessions.id}]")
      end

      deleted += delete_batched(sessions).size
    end

    _log.info("purged stale session data, #{deleted} entries deleted") unless deleted == 0
  end

  def self.delete_batched(sessions)
    where(:id => sessions.collect(&:id)).destroy_all
  end

  def self.timeout(ttl = nil)
    @@timeout = ttl unless ttl.nil?
    @@timeout
  end

  def self.interval(int = nil)
    @@interval = int unless int.nil?
    @@interval
  end
end
