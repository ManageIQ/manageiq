class AuthToken < Authentication
  def auth_key=(val)
    @auth_changed = true if val != auth_key
    super val
  end
end
