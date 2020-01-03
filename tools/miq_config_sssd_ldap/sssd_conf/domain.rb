require 'sssd_conf/common'

module MiqConfigSssdLdap
  class DomainError < StandardError; end

  class Domain < Common
    attr_accessor :active_directory

    def initialize(initial_settings)
      self.active_directory = determine_if_active_directory_configured(initial_settings)

      super(%w[entry_cache_timeout
               ldap_auth_disable_tls_never_use_in_production
               ldap_default_bind_dn
               ldap_default_authtok
               ldap_group_member
               ldap_group_name
               ldap_group_object_class
               ldap_group_search_base
               ldap_network_timeout
               ldap_pwd_policy
               ldap_schema
               ldap_tls_cacert
               ldap_tls_cacertdir
               ldap_uri
               ldap_user_extra_attrs
               ldap_user_gid_number
               ldap_user_name
               ldap_user_object_class
               ldap_user_search_base
               ldap_user_uid_number], initial_settings)
    end

    def entry_cache_timeout
      "600"
    end

    def ldap_auth_disable_tls_never_use_in_production
      initial_settings[:mode] != "ldaps"
    end

    def ldap_default_bind_dn
      initial_settings[:bind_dn]
    end

    def ldap_default_authtok
      initial_settings[:bind_pwd]
    end

    def ldap_group_member
      "member"
    end

    def ldap_group_name
      "cn"
    end

    def ldap_group_object_class
      active_directory? ? "group" : "groupOfNames"
    end

    def ldap_group_search_base
      initial_settings[:basedn]
    end

    def ldap_network_timeout
      "3"
    end

    def ldap_pwd_policy
      "none"
    end

    def ldap_schema
      active_directory? ? "AD" : "rfc2307bis"
    end

    def ldap_tls_cacert
      initial_settings[:tls_cacert] if initial_settings[:mode] == "ldaps"
    end

    def ldap_tls_cacertdir
      initial_settings[:mode] == "ldaps" ? initial_settings[:tls_cacertdir] : "/etc/openldap/cacerts/"
    end

    def ldap_uri
      initial_settings[:ldaphost].map do |host|
        "#{initial_settings[:mode]}://#{host}:#{initial_settings[:ldapport]}"
      end.join(",")
    end

    def ldap_user_extra_attrs
      USER_ATTRS.join(", ")
    end

    def ldap_user_gid_number
      active_directory? ? "primaryGroupID" : "gidNumber"
    end

    def ldap_user_name
      return if active_directory?

      case initial_settings[:user_type]
      when "dn-uid"
        "uid"
      when "dn-cn"
        "cn"
      else
        raise DomainError, "Invalid user_type ->#{initial_settings[:user_type]}<-"
      end
    end

    def ldap_user_object_class
      "person"
    end

    def ldap_user_search_base
      active_directory? ? initial_settings[:basedn] : initial_settings[:user_suffix]
    end

    def ldap_user_uid_number
      "uidNumber"
    end

    private

    def active_directory?
      active_directory
    end

    def determine_if_active_directory_configured(initial_settings)
      case initial_settings[:user_type]
      when "userprincipalname", "mail", "samaccountname"
        true
      when "dn-uid", "dn-cn"
        false
      else
        raise DomainError, "Invalid user_type ->#{initial_settings[:user_type]}<-"
      end
    end
  end
end
