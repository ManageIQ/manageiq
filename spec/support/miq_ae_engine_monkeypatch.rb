module MiqAeEngine
  def self.instantiate(uri)
    Tenant.seed
    user = FactoryGirl.create(:user_with_group)
    MiqAeWorkspaceRuntime.instantiate(uri, user)
  end
end
