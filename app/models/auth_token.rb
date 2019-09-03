class AuthToken < Authentication
  after_update :after_authentication_changed,
    :if => proc { |auth| auth.saved_change_to_auth_key? }

  def self.display_name(number = 1)
    n_('Authentication Token', 'Authentication Tokens', number)
  end
end
