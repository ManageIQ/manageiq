module Authenticator
  class Base
    include Vmdb::Logging

    def self.validate_config(_config)
      []
    end

    def self.authenticates_for
      [name.demodulize.underscore]
    end

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

    def validate_config
      self.class.validate_config(config)
    end

    def uses_stored_password?
      false
    end

    def user_authorizable_without_authentication?
      false
    end

    def authorize_user(userid)
      return unless user_authorizable_without_authentication?
      authenticate(userid, "", {}, {:require_user => true, :authorize_only => true})
    end

    def authenticate(username, password, request = nil, options = {})
      options = options.dup
      options[:require_user] ||= false
      options[:authorize_only] ||= false
      fail_message = _("Authentication failed")

      user_or_taskid = nil

      begin
        username = normalize_username(username)
        audit = {:event => audit_event, :userid => username}

        authenticated = options[:authorize_only] || _authenticate(username, password, request)
        if authenticated
          audit_success(audit.merge(:message => "User #{username} successfully validated by #{self.class.proper_name}"))

          if authorize?
            user_or_taskid = authorize_queue(username, request, options)
          else
            # If role_mode == database we will only use the external system for authentication. Also, the user must exist in our database
            # otherwise we will fail authentication
            user_or_taskid = lookup_by_identity(username, request)
            user_or_taskid ||= autocreate_user(username)

            unless user_or_taskid
              audit_failure(audit.merge(:message => "User #{username} authenticated but not defined in EVM"))
              raise MiqException::MiqEVMLoginError,
                    _("User authenticated but not defined in EVM, please contact your EVM administrator")
            end
          end

          audit_success(audit.merge(:message => "Authentication successful for user #{username}"))
        else
          reason = failure_reason(username, request)
          reason = ": #{reason}" unless reason.blank?
          audit_failure(audit.merge(:message => "Authentication failed for userid #{username}#{reason}"))
          raise MiqException::MiqEVMLoginError, fail_message
        end

      rescue MiqException::MiqEVMLoginError => err
        _log.warn(err.message)
        raise
      rescue Exception => err
        _log.log_backtrace(err)
        raise MiqException::MiqEVMLoginError, err.message
      end

      if options[:require_user] && !user_or_taskid.kind_of?(User)
        task = MiqTask.wait_for_taskid(user_or_taskid, options)
        if task.nil? || MiqTask.status_error?(task.status) || MiqTask.status_timeout?(task.status)
          raise MiqException::MiqEVMLoginError, fail_message
        end
        user_or_taskid = case_insensitive_find_by_userid(task.userid)
      end

      if user_or_taskid.kind_of?(User)
        user_or_taskid.lastlogon = Time.now.utc
        user_or_taskid.save!
      end

      user_or_taskid
    end

    def authorize(taskid, username, *args)
      audit = {:event => "authorize", :userid => username}
      decrypt_ldap_password(config) if MiqLdap.using_ldap?

      run_task(taskid, "Authorizing") do |task|
        begin
          identity = find_external_identity(username, *args)

          unless identity
            msg = "Authentication failed for userid #{username}, unable to find user object in #{self.class.proper_name}"
            _log.warn(msg)
            audit_failure(audit.merge(:message => msg))
            task.error(msg)
            task.state_finished
            return nil
          end

          matching_groups = match_groups(groups_for(identity))
          userid, user = find_or_initialize_user(identity, username)
          update_user_attributes(user, userid, identity)
          audit_new_user(audit, user) if user.new_record?
          user.miq_groups = matching_groups

          if matching_groups.empty?
            msg = "Authentication failed for userid #{user.userid}, unable to match user's group membership to an EVM role"
            _log.warn(msg)
            audit_failure(audit.merge(:message => msg))
            task.error(msg)
            task.state_finished
            user.save! unless user.new_record?
            return nil
          end

          user.lastlogon = Time.now.utc
          user.save!

          _log.info("Authorized User: [#{user.userid}]")
          task.userid = user.userid
          task.update_status("Finished", "Ok", "User authorized successfully")

          user
        rescue Exception => err
          audit_failure(audit.merge(:message => err.message))
          raise
        end
      end
    end

    def find_or_initialize_user(identity, username)
      userid = userid_for(identity, username)
      user   = case_insensitive_find_by_userid(userid)
      user ||= User.new(:userid => userid)
      [userid, user]
    end

    def authenticate_with_http_basic(username, password, request = nil, options = {})
      options[:require_user] ||= false
      user, username = find_by_principalname(username)
      result = nil
      begin
        result = user && authenticate(username, password, request, options)
      rescue MiqException::MiqEVMLoginError
      end
      audit_failure(:userid => username, :message => "Authentication failed for user #{username}") if result.nil?
      [!!result, username]
    end

    def lookup_by_identity(username, *_args)
      case_insensitive_find_by_userid(username)
    end

    # FIXME: LDAP
    def find_by_principalname(username)
      unless (user = case_insensitive_find_by_userid(username))
        if username.include?('\\')
          parts = username.split('\\')
          username = "#{parts.last}@#{parts.first}"
        elsif !username.include?('@') && MiqLdap.using_ldap?
          suffix = config[:user_suffix]
          username = "#{username}@#{suffix}"
        end
        user = case_insensitive_find_by_userid(username)
      end
      [user, username]
    end

    private

    def audit_event
      "authenticate_#{self.class.short_name}"
    end

    def audit_new_user(audit, user)
      msg = "User creation successful for User: #{user.name} with ID: #{user.userid}"
      audit_success(audit.merge(:message => msg))
      MiqEvent.raise_evm_event_queue(MiqServer.my_server, "user_created", :event_details => msg)
    end

    def authorize?
      config[:"#{self.class.short_name}_role"] == true
    end

    def failure_reason(_username, _request)
      nil
    end

    def case_insensitive_find_by_userid(username)
      user =  User.find_by_userid(username)
      user || User.in_my_region.where('lower(userid) = ?', username.downcase).order(:lastlogon).last
    end

    def userid_for(_identity, username)
      username
    end

    def authorize_queue?
      !defined?(Rails::Server)
    end

    def decrypt_ldap_password(config)
      config[:bind_pwd] = MiqPassword.try_decrypt(config[:bind_pwd])
    end

    def encrypt_ldap_password(config)
      config[:bind_pwd] = MiqPassword.try_encrypt(config[:bind_pwd])
    end

    def authorize_queue(username, _request, _options, *args)
      task = MiqTask.create(:name => "#{self.class.proper_name} User Authorization of '#{username}'", :userid => username)
      if authorize_queue?
        encrypt_ldap_password(config) if MiqLdap.using_ldap?
        MiqQueue.submit_job(
          :class_name   => self.class.to_s,
          :method_name  => "authorize",
          :args         => [config, task.id, username, *args],
          :server_guid  => MiqServer.my_guid,
          :priority     => MiqQueue::HIGH_PRIORITY,
          :miq_callback => {
            :class_name  => task.class.name,
            :instance_id => task.id,
            :method_name => :queue_callback_on_exceptions,
            :args        => ['Finished']
          },
        )
      else
        authorize(task.id, username, *args)
      end

      task.id
    end

    def run_task(taskid, status)
      task = MiqTask.find_by(:id => taskid)
      if task.nil?
        message = _("Unable to find task with id: [%{task_id}]") % {:task_id => taskid}
        _log.error(message)
        raise message
      end
      task.update_status("Active", "Ok", status)

      begin
        yield task
      rescue Exception => err
        _log.log_backtrace(err)
        task.error(err.message)
        task.state_finished
        raise
      end
    end

    # TODO: Fix this icky select matching with tenancy
    def match_groups(external_group_names)
      return [] if external_group_names.empty?
      external_group_names = external_group_names.collect(&:downcase)

      internal_groups = MiqGroup.in_my_region.order(:sequence).to_a

      external_group_names.each { |g| _log.debug("External Group: #{g}") }
      internal_groups.each      { |g| _log.debug("Internal Group: #{g.description.downcase}") }

      internal_groups.select { |g| external_group_names.include?(g.description.downcase) }
    end

    def autocreate_user(_username)
      nil
    end

    def normalize_username(username)
      username.downcase
    end

    private def audit_success(options)
      AuditEvent.success(options)
    end

    private def audit_failure(options)
      AuditEvent.failure(options)
      MiqEvent.raise_evm_event_queue(MiqServer.my_server, "login_failed", options)
    end
  end
end
