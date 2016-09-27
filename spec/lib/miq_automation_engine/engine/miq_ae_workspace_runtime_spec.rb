describe MiqAeEngine::MiqAeWorkspaceRuntime do
  let(:root_tenant) { Tenant.seed }
  let(:user) { FactoryGirl.create(:user_with_group) }
  before do
    EvmSpecHelper.local_miq_server
  end

  it "sets current_user" do
    allow_any_instance_of(MiqAeEngine::MiqAeWorkspaceRuntime).to receive(:instantiate)
    MiqAeEngine::MiqAeWorkspaceRuntime.instantiate("/a/b/c", user)

    expect(User.current_user).to eq(user)
  end
end
