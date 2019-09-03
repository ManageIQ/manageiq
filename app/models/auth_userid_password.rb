class AuthUseridPassword < Authentication
  after_update :after_authentication_changed,
    :if => Proc.new{ |auth| auth.saved_change_to_userid || auth.saved_changed_to_password? }

  def self.display_name(number = 1)
    n_('Password', 'Passwords', number)
  end
end
