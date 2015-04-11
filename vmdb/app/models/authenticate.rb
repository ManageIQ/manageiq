module Authenticate
  def self.for(config, username = nil)
    subclass_for(config, username).new(config)
  end

  def self.subclass_for(config, username)
    return Database if username == "admin"

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

    def self.short_name
      name.demodulize.underscore
    end

    attr_reader :config
    def initialize(config)
      @config = config
    end

    def authenticate(username, password, request = nil, options = {})
      options = options.dup
      options[:require_user] ||= false
      fail_message = "Authentication failed"

      user_or_taskid = nil

      begin
        audit = {:event => audit_event, :userid => username}

        username = normalize_username(username)

        if _authenticate(username, password, request)
          AuditEvent.success(audit.merge(:message => "User #{username} successfully validated by #{self.class.proper_name}"))

          if authorize?
            user_or_taskid = authorize_queue(username, request)
          else
            # If role_mode == database we will only use the external system for authentication. Also, the user must exist in our database
            # otherwise we will fail authentication
            user_or_taskid = User.find_by_userid(username)
            user_or_taskid ||= autocreate_user(username, audit)

            unless user_or_taskid
              AuditEvent.failure(audit.merge(:message => "User #{username} authenticated but not defined in EVM"))
              raise MiqException::MiqEVMLoginError, "User authenticated but not defined in EVM, please contact your EVM administrator"
            end
          end

          AuditEvent.success(audit.merge(:message => "Authentication successful for user #{username}"))
        else
          reason = failure_reason
          reason = ": #{reason}" unless reason.blank?
          AuditEvent.failure(audit.merge(:message => "Authentication failed for userid #{username}#{reason}"))
          raise MiqException::MiqEVMLoginError, fail_message
        end

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

    def authorize(taskid, username, *args)
      log_prefix = "MIQ(Authenticate#authorize):"
      audit = {:event => "authorize", :userid => username}

      run_task(taskid, "Authorizing") do |task|
        begin
          identity = find_external_identity(username, *args)

          unless identity
            msg = "Authentication failed for userid #{username}, unable to find user object in #{self.class.proper_name}"
            $log.warn("#{log_prefix}: #{msg}")
            AuditEvent.failure(audit.merge(:message => msg))
            task.error(msg)
            task.state_finished
            return nil
          end

          matching_groups = match_groups(groups_for(identity))
          userid = userid_for(identity, username)
          user   = User.find_by_userid(userid) || User.new(:userid => userid)
          update_user_attributes(user, username, identity)

          if matching_groups.empty?
            msg = "Authentication failed for userid #{user.userid}, unable to match user's group membership to an EVM role"
            AuditEvent.failure(audit.merge(:message => msg))
            $log.warn("#{log_prefix}: #{msg}")
            task.error(msg)
            task.state_finished
            return nil
          end

          user.lastlogon = Time.now.utc
          user.miq_groups = matching_groups
          user.save!

          $log.info("#{log_prefix}: Authorized User: [#{user.userid}]")
          task.userid = user.userid
          task.update_status("Finished", "Ok", "User authorized successfully")

          user
        rescue Exception => err
          AuditEvent.failure(audit.merge(:message => err.message))
          raise
        end
      end
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

    # FIXME: LDAP
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

    private

    def audit_event
      "authenticate_#{self.class.short_name}"
    end

    def authorize?
      p [self.class, :authorize?, :"#{self.class.short_name}_role", config[:"#{self.class.short_name}_role"]]
      config[:"#{self.class.short_name}_role"] == true
    end

    def failure_reason
      nil
    end

    def userid_for(_identity, username)
      username
    end

    def authorize_queue(username, request, *args)
      task = MiqTask.create(:name => "#{self.class.proper_name} User Authorization of '#{username}'", :userid => username)
      unless MiqEnvironment::Process.is_ui_worker_via_command_line?
        cb = {:class_name => task.class.name, :instance_id => task.id, :method_name => :queue_callback_on_exceptions, :args => ['Finished']}
        MiqQueue.put(
          :queue_name   => "generic",
          :class_name   => self.class.to_s,
          :method_name  => "authorize",
          :args         => [config, task.id, username, *args],
          :server_guid  => MiqServer.my_guid,
          :priority     => MiqQueue::HIGH_PRIORITY,
          :miq_callback => cb
        )
      else
        authorize(task.id, username, *args)
      end

      task.id
    end

    def run_task(taskid, status)
      log_prefix = "MIQ(Authenticate#run_task):"

      task = MiqTask.find_by_id(taskid)
      if task.nil?
        message = "#{log_prefix} Unable to find task with id: [#{taskid}]"
        $log.error(message)
        raise message
      end
      task.update_status("Active", "Ok", status)

      begin
        yield task
      rescue Exception => err
        $log.log_backtrace(err)
        task.error(err.message)
        task.state_finished
        raise
      end
    end

    def match_groups(groups)
      log_prefix  = "MIQ(Authenticate#match_groups)"

      return [] if groups.empty?
      groups = groups.collect(&:downcase)

      miq_groups  = MiqServer.my_server.miq_groups
      miq_groups  = MiqServer.my_server.zone.miq_groups if miq_groups.empty?
      miq_groups  = MiqGroup.where(:resource_id => nil, :resource_type => nil) if miq_groups.empty?
      miq_groups  = miq_groups.order(:sequence).to_a
      groups.each       { |g| $log.debug("#{log_prefix} External Group: #{g}") }
      miq_groups.each   { |g| $log.debug("#{log_prefix} Internal Group: #{g.description.downcase}") }
      miq_groups.select { |g| groups.include?(g.description.downcase) }
    end

    def autocreate_user(username)
      nil
    end

    def normalize_username(username)
      username
    end
  end
end
