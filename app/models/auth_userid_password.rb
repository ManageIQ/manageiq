class AuthUseridPassword < Authentication
  def password=(val)
    @auth_changed = true if val != password
    super(val)
  end

  def userid=(val)
    @auth_changed = true if val != userid
    super(val)
  end

  def self.display_name(number = 1)
    n_('Password', 'Passwords', number)
  end
end
