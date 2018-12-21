class AuthenticationRhsm < Authentication
  def self.display_name(number = 1)
    n_('Authentication (RHSM)', 'Authentications (RHSM)', number)
  end
end
