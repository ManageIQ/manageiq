module Authenticator
  class Httpd < Base
    def self.proper_name
      'External httpd'
    end

    def authorize_queue(username, request, options, *_args)
      log_auth_debug("authorize_queue(username=#{username}, options=#{options})")

      user_attrs, membership_list =
        if options[:authorize_only]
          if options[:authorize_with_system_token].present?
            user_details_from_system_token(username, options[:authorize_with_system_token])
          else
            user_details_from_external_directory(username)
          end
        else
          user_details_from_headers(username, request)
        end

      if debug_auth?
        log_auth_debug("authorize_queue user details:")
        user_attrs.each { |k, v| log_auth_debug("  %-12{key} = %{val}" % {:key => k, :val => v}) }
        log_auth_debug("  %-12{key} = %{val}" % {:key => "groups", :val => membership_list.join(', ')})
      end

      super(username, request, {}, user_attrs, membership_list)
    end

    # We don't talk to an external system in #find_external_identity /
    # #groups_for, so no need to enqueue the work
    def authorize_queue?
      false
    end

    def user_authorizable_without_authentication?
      true
    end

    def user_authorizable_with_system_token?
      ext_auth_is_oidc? || ext_auth_is_saml?
    end

    def _authenticate(_username, _password, request)
      request.present? &&
        request.headers['X-REMOTE-USER'].present?
    end

    def failure_reason(_username, request)
      request.headers['X-EXTERNAL-AUTH-ERROR']
    end

    def find_external_identity(_username, user_attrs, membership_list)
      [user_attrs, membership_list]
    end

    def groups_for(identity)
      _user_attrs, membership_list = identity
      MiqGroup.strip_group_domains(membership_list)
    end

    def update_user_attributes(user, username, identity)
      user_attrs, _membership_list = identity

      $audit_log.info("Updating userid from #{user.userid} to #{username}") if user.userid != username
      user.userid     = username
      user.first_name = user_attrs[:firstname]
      user.last_name  = user_attrs[:lastname]
      user.email      = user_attrs[:email] unless user_attrs[:email].blank?
      user.name       = user_attrs[:fullname]
      user.name       = "#{user.first_name} #{user.last_name}" if user.name.blank?
      user.name       = user.userid if user.name.blank?
    end

    def find_or_initialize_user(identity, username)
      user_attrs, _membership_list = identity
      return super if user_attrs[:domain].nil?

      upn_username = username_to_upn_name(user_attrs)
      user = find_userid_as_upn(upn_username)
      user ||= find_userid_as_distinguished_name(user_attrs)
      user ||= find_userid_as_username(identity, username)
      user ||= User.new(:userid => upn_username)

      [upn_username, user]
    end

    def lookup_by_identity(username, request = nil)
      if request
        user_attrs, _membership_list = user_details_from_headers(username, request)
        upn_username = username_to_upn_name(user_attrs)
        user =   find_userid_as_upn(upn_username)
        user ||= find_userid_as_distinguished_name(user_attrs)
      end
      user || case_insensitive_find_by_userid(username)
    end

    private

    def find_userid_as_upn(upn_username)
      case_insensitive_find_by_userid(upn_username)
    end

    def find_userid_as_username(identity, username)
      case_insensitive_find_by_userid(userid_for(identity, username))
    end

    def find_userid_as_distinguished_name(user_attrs)
      dn_domain = user_attrs[:domain].downcase.split(".").map { |s| "dc=#{s}" }.join(",")
      user = User.in_my_region.where("userid LIKE ?", "%=#{user_attrs[:username]},%,#{dn_domain}").last
      user
    end

    def username_to_upn_name(user_attrs)
      return user_attrs[:username] if user_attrs[:domain].nil?

      user_name = user_attrs[:username].split("@").first
      "#{user_name}@#{user_attrs[:domain]}".downcase
    end

    def user_details_from_external_directory(username)
      ext_user_attrs = user_attrs_from_external_directory(username)
      user_attrs = {:username  => username,
                    :fullname  => ext_user_attrs["displayname"],
                    :firstname => ext_user_attrs["givenname"],
                    :lastname  => ext_user_attrs["sn"],
                    :email     => ext_user_attrs["mail"],
                    :domain    => ext_user_attrs["domainname"]}
      [user_attrs, MiqGroup.get_httpd_groups_by_user(username)]
    end

    def user_details_from_headers(username, request)
      if debug_auth?
        log_auth_debug("user_details_from_headers(username=#{username})")

        remote_user_headers = %w[X-REMOTE-USER X-REMOTE-USER-FIRSTNAME X-REMOTE-USER-LASTNAME X-REMOTE-USER-FULLNAME X-REMOTE-USER-EMAIL X-REMOTE-USER-DOMAIN X-REMOTE-USER-GROUPS]
        logged_headers = remote_user_headers.map { |rh| "  %-24{key} = \"%{val}\"" % {:key => rh, :val => request.headers[rh]} }

        log_auth_debug("External-Auth remote user request.headers:")
        log_auth_debug(logged_headers)
      end
      user_attrs = {:username  => username,
                    :fullname  => request.headers['X-REMOTE-USER-FULLNAME'],
                    :firstname => request.headers['X-REMOTE-USER-FIRSTNAME'],
                    :lastname  => request.headers['X-REMOTE-USER-LASTNAME'],
                    :email     => request.headers['X-REMOTE-USER-EMAIL'],
                    :domain    => request.headers['X-REMOTE-USER-DOMAIN']}
      [user_attrs, (CGI.unescape(request.headers['X-REMOTE-USER-GROUPS'] || '')).split(/[;:,]/)]
    end

    def user_details_from_system_token(username, user_metadata)
      return [{}, []] if username != user_metadata[:userid]

      user_attrs = {:username  => user_metadata[:userid],
                    :fullname  => user_metadata[:name],
                    :firstname => user_metadata[:first_name],
                    :lastname  => user_metadata[:last_name],
                    :email     => user_metadata[:email],
                    :domain    => nil}
      [user_attrs, Array(user_metadata[:group_names])]
    end

    def user_attrs_from_external_directory(username)
      if MiqEnvironment::Command.is_podified?
        user_attrs_from_external_directory_via_dbus_api_service(username)
      else
        user_attrs_from_external_directory_via_dbus(username)
      end
    end

    ATTRS_NEEDED = %w(mail givenname sn displayname domainname).freeze

    def user_attrs_from_external_directory_via_dbus(username)
      return unless username
      require "dbus"

      sysbus = DBus.system_bus
      ifp_service   = sysbus["org.freedesktop.sssd.infopipe"]
      ifp_object    = ifp_service.object("/org/freedesktop/sssd/infopipe")
      ifp_object.introspect
      ifp_interface = ifp_object["org.freedesktop.sssd.infopipe"]
      begin
        user_attrs = ifp_interface.GetUserAttr(username, ATTRS_NEEDED).first
      rescue => err
        raise _("Unable to get attributes for external user %{user_name} - %{error}") %
              {:user_name => username, :error => err}
      end

      ATTRS_NEEDED.each_with_object({}) { |attr, hash| hash[attr] = Array(user_attrs[attr]).first }
    end

    def user_attrs_from_external_directory_via_dbus_api_service(username)
      require_dependency "httpd_dbus_api"

      HttpdDBusApi.new.user_attrs(username, ATTRS_NEEDED)
    end

    def ext_auth_is_oidc?
      auth_config = Settings.authentication
      auth_config.mode == "httpd" && auth_config.oidc_enabled && auth_config.provider_type == "oidc"
    end

    def ext_auth_is_saml?
      auth_config = Settings.authentication
      auth_config.mode == "httpd" && auth_config.saml_enabled && auth_config.provider_type == "saml"
    end
  end
end
