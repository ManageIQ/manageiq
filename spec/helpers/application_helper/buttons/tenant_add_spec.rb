describe ApplicationHelper::Button::TenantAdd do
  describe '#role_allows_feature?' do
    let(:session) { {} }
    before do
      MiqProductFeature.seed
      feature = MiqProductFeature.find_all_by_identifier("rbac_tenant_add")
      @view_context = setup_view_context_with_sandbox({})
      @button = tenant_add_button

      role   = FactoryGirl.create(:miq_user_role, :miq_product_features => feature)
      group  = FactoryGirl.create(:miq_group, :miq_user_role => role)
      @user = FactoryGirl.create(:user, :miq_groups => [group])
    end

    def tenant_add_button
      described_class.new(@view_context,
                          {},
                          {'record' => FactoryGirl.create(:tenant)},
                          {:options => {:feature => "rbac_project_add"}, :child_id => "rbac_project_add"})
    end

    it 'returns true for allowed features' do
      login_as @user
      expect(@button.role_allows_feature?).to be_truthy
    end

    it 'returns false for disallowed features' do
      login_as FactoryGirl.create(:user, :role => 'EvmRole-user')
      expect(@button.role_allows_feature?).to be_falsey
    end
  end
end
