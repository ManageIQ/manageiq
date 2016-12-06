shared_context 'server roles' do
  let(:miq_server) { EvmSpecHelper.local_miq_server }

  let(:server_role) do
    FactoryGirl.create(:server_role,
                       :name              => "smartproxy",
                       :description       => "SmartProxy",
                       :max_concurrent    => 1,
                       :external_failover => false,
                       :role_scope        => "zone")
  end

  let(:assigned_server_role) do
    FactoryGirl.create(:assigned_server_role,
                       :miq_server_id  => miq_server.id,
                       :server_role_id => server_role.id,
                       :active         => true,
                       :priority       => 1)
  end
end
