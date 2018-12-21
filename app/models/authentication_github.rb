class AuthenticationGithub < Authentication
  def self.display_name(number = 1)
    n_('Authentication (GitHub)', 'Authentications (GitHub)', number)
  end
end
