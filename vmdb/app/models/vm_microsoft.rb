class VmMicrosoft < VmInfra

  def archived?
    my_management_system.nil? && self.storage.nil?
  end

  def orphaned?
    my_management_system.nil? && !self.storage.nil?
  end

  private

  def my_management_system
    return self.host if self.host && self.host.ext_management_system.nil?
    self.ext_management_system
  end

end
