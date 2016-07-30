require 'bcrypt'
class AuthInternalUseridPassword < AuthUseridPassword
  before_save :set_password_digest

  def set_password_digest
    self.password_digest = BCrypt::Password.create(password)
  end
end
