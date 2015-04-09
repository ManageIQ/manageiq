module Authenticate
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
end
