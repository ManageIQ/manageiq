module Authenticate
  def self.for(config)
    subclass_for(config).new(config)
  end

  def self.subclass_for(config)
    case config[:mode]
    when "database"      then Database
    when "ldap", "ldaps" then Ldap
    when "amazon"        then Amazon
    when "httpd"         then Httpd
    end
  end

  class Base
    def self.authorize(config, *args)
      new(config).authorize(*args)
    end

    attr_reader :config
    def initialize(config)
      @config = config
    end

    def admin_authenticator
      @admin_authenticator ||= Database.new(config)
    end

    def authenticate(username, password, request = nil, options = {})
      if username == "admin"
        admin_authenticator._authenticate(username, password, request, options)
      else
        _authenticate(username, password, request, options)
      end
    end

    def _authenticate(username, password, request = nil, options = {})
      options = options.dup
      options[:require_user] ||= false
      fail_message = "Authentication failed"

      begin
        user_or_taskid = __authenticate(username, password, request)

        raise MiqException::MiqEVMLoginError, fail_message if user_or_taskid.nil?
      rescue MiqException::MiqEVMLoginError => err
        $log.warn err.message
        raise
      rescue Exception => err
        $log.log_backtrace(err)
        raise MiqException::MiqEVMLoginError, err.message
      end

      if options[:require_user] && !user_or_taskid.kind_of?(User)
        task = MiqTask.wait_for_taskid(user_or_taskid, options)
        if task.nil? || MiqTask.status_error?(task.status) || MiqTask.status_timeout?(task.status)
          raise MiqException::MiqEVMLoginError, fail_message
        end
        user_or_taskid = User.find_by_userid(task.userid)
      end

      if user_or_taskid.kind_of?(User)
        user_or_taskid.lastlogon = Time.now.utc
        user_or_taskid.save!
      end

      user_or_taskid
    end

    def authenticate_with_http_basic(username, password, request = nil, options = {})
      options[:require_user] ||= false
      user, username = find_by_principalname(username)
      result = nil
      begin
        result = user.nil? ? nil : authenticate(username, password, request, options)
      rescue MiqException::MiqEVMLoginError
      end
      AuditEvent.failure(:userid => username, :message => "Authentication failed for user #{username}") if result.nil?
      [!!result, username]
    end

    def find_by_principalname(username)
      unless (user = User.find_by_userid(username))
        if username.include?('\\')
          parts = username.split('\\')
          username = "#{parts.last}@#{parts.first}"
        elsif !username.include?('@') && MiqLdap.using_ldap?
          suffix = config[:user_suffix]
          username = "#{username}@#{suffix}"
        end
        user = User.find_by_userid(username)
      end
      [user, username]
    end
  end
end
