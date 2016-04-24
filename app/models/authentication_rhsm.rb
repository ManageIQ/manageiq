class AuthenticationRhsm < Authentication
  alias_attribute :rhsm_user, :userid
  alias_attribute :rhsm_pass, :password
  alias_attribute :rhsm_activation_key, :auth_key
  def assign_values(options)
    super
  end
end
