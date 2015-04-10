module Authenticate
  class Httpd < Base
    def self.proper_name
      'External httpd'
    end

    def authorize_queue(username, request)
      user_attrs = {:username  => username,
                    :fullname  => request.headers['X_REMOTE_USER_FULLNAME'],
                    :firstname => request.headers['X_REMOTE_USER_FIRSTNAME'],
                    :lastname  => request.headers['X_REMOTE_USER_LASTNAME'],
                    :email     => request.headers['X_REMOTE_USER_EMAIL']}
      membership_list = (request.headers['X_REMOTE_USER_GROUPS'] || '').split(":")

      super(username, request, user_attrs, membership_list)
    end

    def _authenticate(_username, _password, request)
      request.present? &&
        request.headers['X_REMOTE_USER'].present?
    end

    def failure_reason
      request.headers['HTTP_X_EXTERNAL_AUTH_ERROR']
    end

    def find_external_identity(_username, user_attrs, membership_list)
      [user_attrs, membership_list]
    end

    def groups_for(opaque)
      _user_attrs, membership_list = opaque
      membership_list
    end

    def update_user_attributes(user, opaque)
      user_attrs, _membership_list = opaque

      user.userid     = user_attrs[:username]
      user.name       = user_attrs[:fullname]
      user.first_name = user_attrs[:firstname]
      user.last_name  = user_attrs[:lastname]
      user.email      = user_attrs[:email] unless user_attrs[:email].blank?
    end
  end
end
