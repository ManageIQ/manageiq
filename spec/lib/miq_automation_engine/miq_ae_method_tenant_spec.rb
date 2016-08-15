describe "MiqAeMethodWithTenat" do
  include Spec::Support::AutomationHelper

  let(:user) { FactoryGirl.create(:user_with_group) }
  let(:user2) { FactoryGirl.create(:user_with_group) }

  before do
    method_script = "$evm.root['result'] = {:tenant_id => $evm.root['tenant'].id,
                                            :user_id   => $evm.root['user'].id,
                                            :group_id  => $evm.root['miq_group'].id}"
    create_ae_model_with_method(:method_script => method_script, :ae_class => 'AUTOMATE',
                                :ae_namespace  => 'EVM', :instance_name => 'test1',
                                :method_name   => 'test', :name => 'TEST_DOMAIN')
  end

  def invoke_ae(url, user)
    MiqAeEngine.instantiate(url, user)
  end

  context "automate method" do
    it "ignore user in url" do
      result = invoke_ae("/EVM/AUTOMATE/test1?User::user=#{user2.id}", user).root['result']

      expect(result[:tenant_id]).to eql(Tenant.root_tenant.id)
      expect(result[:user_id]).to eql(user.id)
      expect(result[:group_id]).to eql(user.current_group.id)
    end

    it "use the passed in user object" do
      result = invoke_ae("/EVM/AUTOMATE/test1", user).root['result']

      expect(result[:tenant_id]).to eql(Tenant.root_tenant.id)
      expect(result[:user_id]).to eql(user.id)
      expect(result[:group_id]).to eql(user.current_group.id)
    end
  end
end
