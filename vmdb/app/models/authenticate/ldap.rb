module Authenticate
  class Ldap < Base
    def self.proper_name
      'LDAP'
    end

    def verify_ldap_credentials(username, password)
      username = normalize(username)
      raise MiqException::MiqEVMLoginError, "authentication failed" unless ldap.bind(username, password)
    end

    def find_or_create_by_ldap_attr(attr, value)
      user = User.find_by_userid(value)
      return user if user

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

      matching_groups = match_groups(groups_for(uobj))
      raise "Unable to auto-create user because unable to match user's group membership to an EVM role" if matching_groups.empty?

      user = User.new
      update_user_attributes(user, uobj)
      user.miq_groups = matching_groups
      user.save

      $log.info("MIQ(Authenticate#find_or_create_by_ldap_attr): Created User: [#{user.userid}]")

      user
    end

    private

    def ldap
      @ldap ||= MiqLdap.new
    end

    def autocreate_user(username)
      default_group = MiqGroup.where(:description => config[:default_group_for_users]).first if config[:default_group_for_users]
      if default_group
        # when default group for ldap users is enabled, create the user
        user = User.new
        lobj = ldap.get_user_object(username)
        update_user_attributes(user, lobj)
        user.save_successful_logon([default_group], audit)
        $log.info("MIQ(Authenticate#autocreate_user): Created User: [#{user.userid}]")

        user
      end
    end

    def normalize_username(username)
      ldap.normalize(ldap.fqusername(username))
    end

    def _authenticate(username, password, _request)
      password.present? &&
        ldap.bind(username, password)
    end

    def find_external_identity(username)
      # Ldap will be used for authentication and role assignment
      $log.info("#{log_prefix} Bind DN: [#{config[:bind_dn]}]")
      ldap.bind(config[:bind_dn], config[:bind_pwd]) # now bind with bind_dn so that we can do our searches.
      $log.info("#{log_prefix}  User FQDN: [#{username}]")
      lobj = ldap.get_user_object(username)
      $log.debug("#{log_prefix} User obj from LDAP: #{lobj.inspect}")

      lobj
    end

    def userid_for(lobj, username)
      ldap.normalize(ldap.get_attr(lobj, :userprincipalname) || username)
    end

    def groups_for(lobj)
      authentication = config.dup
      authentication[:group_memberships_max_depth] ||= DEFAULT_GROUP_MEMBERSHIPS_MAX_DEPTH

      if authentication.key?(:user_proxies)       && !authentication[:user_proxies].blank?  &&
         authentication.key?(:get_direct_groups)  && authentication[:get_direct_groups] == false
        $log.info("MIQ(Authenticate#groups_for) Skipping getting group memberships directly assigned to user bacause it has been disabled in the configuration")
        groups = []
      else
        groups = ldap.get_memberships(obj, authentication[:group_memberships_max_depth])
      end

      if authentication.key?(:user_proxies)
        if (sid = MiqLdap.get_attr(obj, :objectsid))
          authentication[:user_proxies].each do |auth|
            begin
              groups += user_proxy_membership(auth, MiqLdap.sid_to_s(sid))
            rescue Exception => err
              $log.warn("MIQ(Authenticate#groups_for) #{err.message} (from Authenticate#user_proxy_membership)")
            end
          end
        else
          $log.warn("MIQ(Authenticate#groups_for) User Object has no objectSID")
        end
      end

      groups.uniq
    end

    def update_user_attributes(user, lobj)
      user.userid     = ldap.normalize(ldap.get_attr(lobj, :userprincipalname) || ldap.get_attr(lobj, :dn))
      user.name       = ldap.get_attr(lobj, :displayname)
      user.first_name = ldap.get_attr(lobj, :givenname)
      user.last_name  = ldap.get_attr(lobj, :sn)
      email           = ldap.get_attr(lobj, :mail)
      user.email      = email unless email.blank?
    end

    REQUIRED_LDAP_USER_PROXY_KEYS = [:basedn, :bind_dn, :bind_pwd, :ldaphost, :ldapport, :mode]
    def user_proxy_membership(auth, sid)
      log_prefix = "MIQ(Authenticate#user_proxy_membership)"

      authentication    = config
      auth[:bind_dn]  ||= authentication[:bind_dn]
      auth[:bind_pwd] ||= authentication[:bind_pwd]
      auth[:ldapport] ||= authentication[:ldapport]
      auth[:mode]     ||= authentication[:mode]
      auth[:group_memberships_max_depth] ||= DEFAULT_GROUP_MEMBERSHIPS_MAX_DEPTH

      REQUIRED_LDAP_USER_PROXY_KEYS.each { |key| raise "Required key not specified: [#{key}]" unless auth.key?(key) }

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
  end
end
