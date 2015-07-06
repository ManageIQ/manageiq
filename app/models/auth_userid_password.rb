class AuthUseridPassword < Authentication
  # The validate lines were commented out as part of the Rails 2.1 upgrade
  # due to unexpected errors raised.  This needs additional research.
# validates_presence_of     :name, :userid
# validates_uniqueness_of   :name

  def password=(val)
    @auth_changed = true if val != self.password
    super val
  end

  def userid=(val)
    @auth_changed = true if val != self.userid
    super val
  end

end
