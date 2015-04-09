module Authenticate
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
end
