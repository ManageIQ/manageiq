class AuthUseridPassword < Authentication
  def self.display_name(number = 1)
    n_('Password', 'Passwords', number)
  end
end
