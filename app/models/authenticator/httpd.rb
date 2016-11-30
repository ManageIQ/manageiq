module Authenticator
  class Httpd < Base
    def self.proper_name
      'External httpd'
    end

    def authorize_queue(username, request, options, *_args)
      if options[:authorize_only] == true
        ext_user_attrs = get_user_attrs(username)
        user_attrs = {:username  => username,
                      :fullname  => ext_user_attrs["displayname"],
                      :firstname => ext_user_attrs["givenname"],
                      :lastname  => ext_user_attrs["sn"],
                      :email     => ext_user_attrs["mail"]}
        membership_list = MiqGroup.get_httpd_groups_by_user(username)
      else
        user_attrs = {:username  => username,
                      :fullname  => request.headers['X-REMOTE-USER-FULLNAME'],
                      :firstname => request.headers['X-REMOTE-USER-FIRSTNAME'],
                      :lastname  => request.headers['X-REMOTE-USER-LASTNAME'],
                      :email     => request.headers['X-REMOTE-USER-EMAIL']}
        membership_list = (request.headers['X-REMOTE-USER-GROUPS'] || '').split(/[;:]/)
      end

      super(username, request, {}, user_attrs, membership_list)
    end

    # We don't talk to an external system in #find_external_identity /
    # #groups_for, so no need to enqueue the work
    def authorize_queue?
      false
    end

    def authorize_user_by_userid?
      true
    end

    def get_user_attrs(username)
      return unless username
      require "dbus"

      attrs_needed = %w(mail givenname sn displayname)

      sysbus = DBus.system_bus
      ifp_service   = sysbus["org.freedesktop.sssd.infopipe"]
      ifp_object    = ifp_service.object "/org/freedesktop/sssd/infopipe"
      ifp_object.introspect
      ifp_interface = ifp_object["org.freedesktop.sssd.infopipe"]
      begin
        user_attrs = ifp_interface.GetUserAttr(username, attrs_needed).first
      rescue => err
        raise _("Unable to get attributes for external user %{user_name} - %{error}") %
              {:user_name => username, :error => err}
      end

      attrs_needed.each_with_object({}) { |attr, hash| hash[attr] = Array(user_attrs[attr]).first }
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

    def update_user_attributes(user, _username, identity)
      user_attrs, _membership_list = identity

      user.userid     = user_attrs[:username]
      user.name       = user_attrs[:fullname]
      user.first_name = user_attrs[:firstname]
      user.last_name  = user_attrs[:lastname]
      user.email      = user_attrs[:email] unless user_attrs[:email].blank?
    end
  end
end
