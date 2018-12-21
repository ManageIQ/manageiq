class AuthenticationHtpasswd < Authentication
  def self.display_name(number = 1)
    n_('Authentication (HTTP Password)', 'Authentications (HTTP Password)', number)
  end
end
