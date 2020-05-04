module Authenticator
  class Database < Base
    def self.proper_name
      'EVM'
    end

    def uses_stored_password?
      true
    end

    private

    def _authenticate(username, password, _request)
      user = case_insensitive_find_by_userid(username)

      return [false, _('Your account has been locked due to too many failed login attempts, please contact the administrator.')] if user&.locked?

      if user&.authenticate_bcrypt(password) # Authenticate if the username matches
        user.unlock! # Reset the number of failed logins
        return true
      end

      user&.fail_login! # Increase the number of failed login attempts
      [false, _("The username or password you entered is incorrect.")]
    end

    def authorize?
      false
    end
  end
end
