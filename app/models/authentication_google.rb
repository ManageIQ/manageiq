class AuthenticationGoogle < Authentication
  def self.display_name(number = 1)
    n_('Authentication (Google)', 'Authentications (Google)', number)
  end
end
