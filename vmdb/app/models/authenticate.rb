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

  class Database < Base
    def admin_authenticator
      self
    end

    def __authenticate(username, password, request)
      audit = {:event => "authenticate_database", :message => "Authentication failed for user #{username}", :userid => username}
      user = User.find_by_userid(username)

      if user.nil? || !(user.authenticate_bcrypt(password))
        AuditEvent.failure(audit)
        return nil
      end
      AuditEvent.success(audit.merge(:message => "Authentication successful for user #{username}"))

      user
    end
  end

  class Ldap < Base
    def verify_ldap_credentials(username, password)
      ldap = MiqLdap.new
      fq_user = ldap.normalize(ldap.fqusername(username))
      raise MiqException::MiqEVMLoginError, "authentication failed" unless ldap.bind(fq_user, password)
    end

    def __authenticate(username, password, request)
      audit = {:event => "authenticate_ldap", :userid => username}
      if password.blank?
        AuditEvent.failure(audit.merge(:message => "Authentication failed for user #{username}"))
        return nil
      end

      ldap = MiqLdap.new
      fq_user = ldap.normalize(ldap.fqusername(username))

      if ldap.bind(fq_user, password)
        AuditEvent.success(audit.merge(:message => "User #{fq_user} successfully binded to LDAP directory"))

        if config[:ldap_role] == true
          user = authorize_queue(fq_user)
        else
          # If role_mode == database we will only use ldap for authentication. Also, the user must exist in our database
          # otherwise we will fail authentication
          user = User.find_by_userid(fq_user)

          default_group = MiqGroup.where(:description => config[:default_group_for_users]).first if config[:default_group_for_users]
          if user.nil? && default_group
            # when default group for ldap users is enabled, create the user
            user = User.new
            lobj = ldap.get_user_object(fq_user)
            user.update_attrs_from_ldap(ldap, lobj)
            user.save_successful_logon([default_group], audit)
            $log.info("MIQ(User.authenticate_ldap): Created User: [#{user.userid}]")
          end

          unless user
            AuditEvent.failure(audit.merge(:message => "User #{fq_user} authenticated but not defined in EVM"))
            raise MiqException::MiqEVMLoginError, "User authenticated but not defined in EVM, please contact your EVM administrator"
          end
        end

        AuditEvent.success(audit.merge(:message => "Authentication successful for user #{fq_user}"))
        user
      else
        AuditEvent.failure(audit.merge(:message => "Authentication failed for userid #{fq_user}"))
        nil
      end
    end

    def authorize_queue(fq_user)
      task = MiqTask.create(:name => "LDAP User Authorization of '#{fq_user}'", :userid => fq_user)
      unless MiqEnvironment::Process.is_ui_worker_via_command_line?
        cb = {:class_name => task.class.name, :instance_id => task.id, :method_name => :queue_callback_on_exceptions, :args => ['Finished']}
        MiqQueue.put(
          :queue_name   => "generic",
          :class_name   => self.class.to_s,
          :method_name  => "authorize",
          :args         => [config, task.id, fq_user],
          :server_guid  => MiqServer.my_guid,
          :priority     => MiqQueue::HIGH_PRIORITY,
          :miq_callback => cb
        )
      else
        authorize(task.id, fq_user)
      end

      task.id
    end

    def authorize(taskid, fq_user)
      log_prefix = "MIQ(User.authorize):"
      audit = {:event => "authorize", :userid => fq_user}

      task = MiqTask.find_by_id(taskid)
      if task.nil?
        message = "#{log_prefix} Unable to find task with id: [#{taskid}]"
        $log.error(message)
        raise message
      end
      task.update_status("Active", "Ok", "Authorizing")

      begin
        # Ldap will be used for authentication and role assignment
        $log.info("#{log_prefix} Bind DN: [#{config[:bind_dn]}]")
        ldap = MiqLdap.new
        ldap.bind(config[:bind_dn], config[:bind_pwd]) # now bind with bind_dn so that we can do our searches.
        $log.info("#{log_prefix}  User FQDN: [#{fq_user}]")
        lobj = ldap.get_user_object(fq_user)
        $log.debug("#{log_prefix} User obj from LDAP: #{lobj.inspect}")
        unless lobj
          msg = "Authentication failed for userid #{fq_user}, unable to find user object in LDAP"
          $log.warn("#{log_prefix}: #{msg}")
          AuditEvent.failure(audit.merge(:message => msg))
          task.error(msg)
          task.state_finished
          return nil
        end

        matching_groups = match_groups(getUserMembership(ldap, lobj))
        userid = ldap.normalize(ldap.get_attr(lobj, :userprincipalname) || fq_user)
        user   = User.find_by_userid(userid) || User.new(:userid => userid)
        user.update_attrs_from_ldap(ldap, lobj)
        user.save_successful_logon(matching_groups, audit, task)
      rescue Exception => err
        $log.log_backtrace(err)
        task.error(err.message)
        AuditEvent.failure(audit.merge(:message => err.message))
        task.state_finished
        raise
      end
    end

    private

    REQUIRED_LDAP_USER_PROXY_KEYS = [:basedn, :bind_dn, :bind_pwd, :ldaphost, :ldapport, :mode]
    def getUserProxyMembership(auth, sid)
      log_prefix = "MIQ(User.getUserProxyMembership)"

      authentication    = config
      auth[:bind_dn]  ||= authentication[:bind_dn]
      auth[:bind_pwd] ||= authentication[:bind_pwd]
      auth[:ldapport] ||= authentication[:ldapport]
      auth[:mode]     ||= authentication[:mode]
      auth[:group_memberships_max_depth] ||= DEFAULT_GROUP_MEMBERSHIPS_MAX_DEPTH

      REQUIRED_LDAP_USER_PROXY_KEYS.each { |key| raise "Required key not specified: [#{key}]" unless auth.has_key?(key) }

      fsp_dn  = "cn=#{sid},CN=ForeignSecurityPrincipals,#{auth[:basedn]}"

      ldap_up = MiqLdap.new(:auth => {:ldaphost => auth[:ldaphost], :ldapport => auth[:ldapport], :mode => auth[:mode], :basedn => auth[:basedn]})

      $log.info("#{log_prefix} Bind DN: [#{auth[:bind_dn]}], Host: [#{auth[:ldaphost]}], Port: [#{auth[:ldapport]}], Mode: [#{auth[:mode]}]")
      raise "Cannot Bind" unless ldap_up.bind(auth[:bind_dn], auth[:bind_pwd]) # now bind with bind_dn so that we can do our searches.
      $log.info("#{log_prefix} User SID: [#{sid}], FSP DN: [#{fsp_dn}]")
      user_proxy_object = ldap_up.search(:base => fsp_dn, :scope => :base).first
      raise "Unable to find user proxy object in LDAP" if user_proxy_object.nil?
      $log.debug("#{log_prefix} UserProxy obj from LDAP: #{user_proxy_object.inspect}")
      ldap_up.get_memberships(user_proxy_object, auth[:group_memberships_max_depth])
    end

    def getUserMembership(ldap, obj)
      authentication = config.dup
      authentication[:group_memberships_max_depth] ||= DEFAULT_GROUP_MEMBERSHIPS_MAX_DEPTH

      if authentication.key?(:user_proxies)       && !authentication[:user_proxies].blank?  &&
         authentication.key?(:get_direct_groups)  && authentication[:get_direct_groups] == false
        $log.info("MIQ(User.getUserMembership) Skipping getting group memberships directly assigned to user bacause it has been disabled in the configuration")
        groups = []
      else
        groups = ldap.get_memberships(obj, authentication[:group_memberships_max_depth])
      end

      if authentication.key?(:user_proxies)
        sid = MiqLdap.get_attr(obj, :objectsid)
        $log.warn("MIQ(User.getUserMembership) User Object has no objectSID") if sid.nil?

        authentication[:user_proxies].each do |auth|
          begin
            groups += getUserProxyMembership(auth, MiqLdap.sid_to_s(sid))
          rescue Exception => err
            $log.warn("MIQ(User.getUserMembership) #{err.message} (from User.getUserProxyMembership)")
          end
        end unless sid.nil?
      end

      groups.uniq
    end

    def match_groups(groups)
      log_prefix  = "MIQ(User#match_groups)"

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

    public

    def find_or_create_by_ldap_attr(attr, value)
      user = User.find_by_userid(value)
      return user if user

      ldap = MiqLdap.new

      user = case attr
             when "mail"
               User.find_by_email(value)
             when "userprincipalname"
               value = ldap.fqusername(value)
               User.find_by_userid(value)
             else
               raise "Attribute '#{attr}' is not supported"
             end

      return user unless user.nil?

      raise "Unable to auto-create user because LDAP authentication is not enabled"       unless config[:mode] == "ldap" || config[:mode] == "ldaps"
      raise "Unable to auto-create user because LDAP bind credentials are not configured" unless config[:ldap_role] == true

      ldap.bind(config[:bind_dn], config[:bind_pwd]) # now bind with bind_dn so that we can do our searches.

      uobj = ldap.get_user_object(value, attr)
      raise "Unable to auto-create user because LDAP search returned no data for user with #{attr}: [#{value}]" if uobj.nil?

      matching_groups = match_groups(getUserMembership(ldap, uobj))
      raise "Unable to auto-create user because unable to match user's group membership to an EVM role" if matching_groups.empty?

      user = User.new
      user.update_attrs_from_ldap(ldap, uobj)
      user.miq_groups = matching_groups
      user.save

      $log.info("MIQ(User.find_or_create_by_ldap_attr): Created User: [#{user.userid}]")

      user
    end
  end

  class Amazon < Base
    def __authenticate(username, password, request)
      audit = {:event => "authenticate_amazon", :userid => username}
      if password.blank?
        AuditEvent.failure(audit.merge(:message => "Authentication failed for user #{username}"))
        return nil
      end

      amazon_auth = AmazonAuth.new
      if amazon_auth.iam_authenticate(username, password)
        AuditEvent.success(audit.merge(:message => "User #{username} successfully validated as Amazon IAM user"))

        if config[:amazon_role] == true
          user = authorize_queue(username)
        else
          # If role_mode == database we will only use amazon for authentication. Also, the user must exist in our database
          # otherwise we will fail authentication
          user = User.find_by_userid(username)
          unless user
            AuditEvent.failure(audit.merge(:message => "User #{username} authenticated but not defined in EVM"))
            raise MiqException::MiqEVMLoginError, "User authenticated but not defined in EVM, please contact your EVM administrator"
          end
          return nil unless user
        end

        AuditEvent.success(audit.merge(:message => "Authentication successful for user #{username}"))
        user
      else
        AuditEvent.failure(audit.merge(:message => "Authentication failed for userid #{username}"))
        nil
      end
    end

    def authorize_queue(username)
      task = MiqTask.create(:name => "Amazon IAM User Authorization of '#{username}'", :userid => username)
      unless MiqEnvironment::Process.is_ui_worker_via_command_line?
        cb = {:class_name => task.class.name, :instance_id => task.id, :method_name => :queue_callback_on_exceptions, :args => ['Finished']}
        MiqQueue.put(
          :queue_name   => "generic",
          :class_name   => self.class.to_s,
          :method_name  => "authorize",
          :args         => [config, task.id, username],
          :server_guid  => MiqServer.my_guid,
          :priority     => MiqQueue::HIGH_PRIORITY,
          :miq_callback => cb
        )
      else
        authorize(task.id, username)
      end

      task.id
    end

    def authorize(taskid, username)
      log_prefix = "MIQ(User.authorize):"
      audit = {:event => "authorize", :userid => username}

      task = MiqTask.find_by_id(taskid)
      if task.nil?
        message = "#{log_prefix} Unable to find task with id: [#{taskid}]"
        $log.error(message)
        raise message
      end
      task.update_status("Active", "Ok", "Authorizing")

      begin
        # Amazon IAM will be used for authentication and role assignment
        $log.info("#{log_prefix} AWS key: [#{config[:amazon_key]}]")
        amazon_auth = AmazonAuth.new(:auth => config)
        $log.info("#{log_prefix}  User: [#{username}]")
        amazon_user = amazon_auth.iam_user(username)
        $log.debug("#{log_prefix} User obj from Amazon: #{amazon_user.inspect}")
        unless amazon_user
          msg = "Authentication failed for userid #{username}, unable to find IAM user object in Amazon"
          $log.warn("#{log_prefix}: #{msg}")
          AuditEvent.failure(audit.merge(:message => msg))
          task.error(msg)
          task.state_finished
          return nil
        end

        matching_groups = match_groups(amazon_auth.get_memberships(amazon_user))
        user   = User.find_by_userid(username) || User.new(:userid => username)
        user.update_attrs_from_iam(amazon_auth, amazon_user, username)
        user.save_successful_logon(matching_groups, audit, task)
      rescue Exception => err
        $log.log_backtrace(err)
        task.error(err.message)
        AuditEvent.failure(audit.merge(:message => err.message))
        task.state_finished
        raise
      end
    end
  end

  class Httpd < Base
    def __authenticate(username, password, request)
      audit = {:event => "authenticate_httpd", :userid => username}
      if request.nil?
        AuditEvent.failure(audit.merge(:message => "Authentication failed for user #{username}, request missing"))
        nil
      elsif request.headers['X_REMOTE_USER'].present?
        AuditEvent.success(audit.merge(:message => "User #{username} successfully validated by httpd"))

        if config[:httpd_role] == true
          user = authorize_queue(username, request)
        else
          # If role_mode == database we will only use httpd for authentication. Also, the user must exist in our database
          # otherwise we will fail authentication
          unless (user = User.find_by_userid(username))
            AuditEvent.failure(audit.merge(:message => "User #{username} authenticated but not defined in EVM"))
            raise MiqException::MiqEVMLoginError,
                  "User authenticated but not defined in EVM, please contact your EVM administrator"
          end
        end

        AuditEvent.success(audit.merge(:message => "Authentication successful for user #{username}"))
        user
      else
        external_auth_error = request.headers['HTTP_X_EXTERNAL_AUTH_ERROR']
        AuditEvent.failure(audit.merge(:message => "Authentication failed for userid #{username} #{external_auth_error}"))
        nil
      end
    end

    def authorize_queue(username, request)
      task = MiqTask.create(:name => "External httpd User Authorization of '#{username}'", :userid => username)
      user_attrs = {:username  => username,
                    :fullname  => request.headers['X_REMOTE_USER_FULLNAME'],
                    :firstname => request.headers['X_REMOTE_USER_FIRSTNAME'],
                    :lastname  => request.headers['X_REMOTE_USER_LASTNAME'],
                    :email     => request.headers['X_REMOTE_USER_EMAIL']}
      membership_list = (request.headers['X_REMOTE_USER_GROUPS'] || '').split(":")

      if !MiqEnvironment::Process.is_ui_worker_via_command_line?
        authorize(task.id, username, user_attrs, membership_list)
      else
        MiqQueue.put(
          :queue_name   => "generic",
          :class_name   => self.class.to_s,
          :method_name  => "authorize",
          :args         => [config, task.id, username, user_attrs, membership_list],
          :server_guid  => MiqServer.my_guid,
          :priority     => MiqQueue::HIGH_PRIORITY,
          :miq_callback => {
            :class_name  => task.class.name,
            :instance_id => task.id,
            :method_name => :queue_callback_on_exceptions,
            :args        => ['Finished']
          })
      end

      task.id
    end

    def authorize(taskid, username, user_attrs, membership_list)
      log_prefix = "MIQ(User.authorize):"
      audit = {:event => "authorize", :userid => username}

      task = MiqTask.find_by_id(taskid)
      if task.nil?
        message = "#{log_prefix} Unable to find task with id: [#{taskid}]"
        $log.error(message)
        raise message
      end
      task.update_status("Active", "Ok", "Authorizing")

      begin
        $log.info("#{log_prefix}  User: [#{username}]")

        matching_groups = match_groups(membership_list)
        user = User.find_by_userid(username) || User.new(:userid => username)
        user.update_attrs_from_httpd(user_attrs)
        user.save_successful_logon(matching_groups, audit, task)
      rescue => err
        $log.log_backtrace(err)
        task.error(err.message)
        AuditEvent.failure(audit.merge(:message => err.message))
        task.state_finished
        raise
      end
    end
  end
end
