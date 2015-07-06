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
      user = User.find_by_userid(username)

      user && user.authenticate_bcrypt(password)
    end

    def authorize?
      false
    end
  end
end
