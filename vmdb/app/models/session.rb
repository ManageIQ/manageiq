class Session < ActiveRecord::Base
  @@timeout = 3600 # session time to live in seconds
  @@interval = 30 # how often to purge in seconds
  @@job ||= nil

  def self.check_session_timeout
    $log.debug "Checking session data"
    ttl = self.timeout
    cfg = VMDB::Config.new("vmdb").config[:session]
    ttl = cfg[:timeout] if cfg[:timeout].to_int != ttl
    self.purge(ttl)
  end

  def self.purge(ttl)
    ses = self.where("updated_at <= ?", ttl.seconds.ago.utc)
    ses.each{|s|
      begin
        userid = Marshal.load(Base64.decode64(s.data.split("\n").join))[:userid]
        user = User.find_by_userid(userid)
        if user && ((user.lastlogoff && user.lastlogon && user.lastlogoff < user.lastlogon) || (user.lastlogon && user.lastlogoff.nil?))
         user.logoff
        end
      rescue Exception
      end

      s.destroy
    }
    $log.info("MIQ(session-purge) purged stale session data, #{ses.length} entries deleted") unless ses.length == 0
  end

  def self.timeout(ttl=nil)
    @@timeout = ttl unless ttl == nil
    return @@timeout
  end

  def self.interval(int=nil)
    @@interval = int unless int == nil
    return @@interval
  end
end
