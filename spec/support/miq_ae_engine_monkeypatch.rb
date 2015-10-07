module MiqAeEngine
  def self.instantiate(uri)
    EvmSpecHelper.create_root_tenant
    user = FactoryGirl.create(:user_with_group)
    MiqAeWorkspaceRuntime.instantiate(uri, user)
  end
end
