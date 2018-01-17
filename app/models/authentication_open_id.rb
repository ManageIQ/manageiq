class AuthenticationOpenId < Authentication
  def self.display_name(number = 1)
    n_('Authentication (OpenID)', 'Authentications (OpenID)', number)
  end
end
