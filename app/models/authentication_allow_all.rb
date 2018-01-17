class AuthenticationAllowAll < Authentication
  def self.display_name(number = 1)
    n_('Authentication (Allow All)', 'Authentications (Allow All)', number)
  end
end
