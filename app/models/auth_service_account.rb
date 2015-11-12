class AuthServiceAccount < Authentication
  def service_account=(val)
    @auth_changed = true if val != service_account
    super val
  end
end
