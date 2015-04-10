module Authenticate
  class Amazon < Base
    def self.proper_name
      'Amazon IAM'
    end

    def amazon_auth
      @amazon_auth ||= AmazonAuth.new
    end

    def _authenticate(username, password, _request)
      password.present? &&
        amazon_auth.iam_authenticate(username, password)
    end

    def find_external_identity(username)
      # Amazon IAM will be used for authentication and role assignment
      $log.info("#{log_prefix} AWS key: [#{config[:amazon_key]}]")
      $log.info("#{log_prefix}  User: [#{username}]")
      amazon_user = amazon_auth.iam_user(username)
      $log.debug("#{log_prefix} User obj from Amazon: #{amazon_user.inspect}")

      amazon_user
    end

    def groups_for(amazon_user)
      amazon_auth.get_memberships(amazon_user)
    end

    def update_user_attributes(user, amazon_user)
      user.userid = username
      user.name   = amazon_user.name
    end
  end
end
