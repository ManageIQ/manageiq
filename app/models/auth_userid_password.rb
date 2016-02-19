class AuthUseridPassword < Authentication
  def password=(val)
    @auth_changed = true if val != password
    super val
  end

  def userid=(val)
    @auth_changed = true if val != userid
    super val
  end
end
