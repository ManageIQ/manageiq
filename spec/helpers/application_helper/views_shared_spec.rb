describe ApplicationHelper do
  describe '#ownership_user_options' do
    let(:child_tenant)                  { FactoryGirl.create(:tenant) }
    let(:grand_child_tenant)            { FactoryGirl.create(:tenant, :parent => child_tenant) }
    let(:great_grand_child_tenant)      { FactoryGirl.create(:tenant, :parent => grand_child_tenant) }
    let(:child_role)                    { FactoryGirl.create(:miq_user_role) }
    let(:grand_child_tenant_role)       { FactoryGirl.create(:miq_user_role) }
    let(:great_grand_child_tenant_role) { FactoryGirl.create(:miq_user_role) }
    let(:child_group)                   { FactoryGirl.create(:miq_group, :role => child_role, :tenant => child_tenant) }
    let(:grand_child_group) do
      FactoryGirl.create(:miq_group, :role   => grand_child_tenant_role,
                                     :tenant => grand_child_tenant)
    end
    let(:great_grand_child_group) do
      FactoryGirl.create(:miq_group, :role   => great_grand_child_tenant_role,
                                     :tenant => great_grand_child_tenant)
    end
    let!(:admin_user)             { FactoryGirl.create(:user_admin) }
    let!(:child_user)             { FactoryGirl.create(:user, :miq_groups => [child_group]) }
    let!(:grand_child_user)       { FactoryGirl.create(:user, :miq_groups => [grand_child_group]) }
    let!(:great_grand_child_user) { FactoryGirl.create(:user, :miq_groups => [great_grand_child_group]) }

    subject { helper.ownership_user_options }
    context 'admin user' do
      it 'lists all users' do
        allow(User).to receive(:server_timezone).and_return('UTC')
        allow(User).to receive(:current_user).and_return(admin_user)
        expect(subject.count).to eq(User.count)
      end
    end

    context 'a tenant user' do
      it 'lists users in that tenant' do
        allow(User).to receive(:server_timezone).and_return('UTC')
        allow(User).to receive(:current_user).and_return(grand_child_user)

        ids = [great_grand_child_tenant, grand_child_tenant].collect(&:user_ids).flatten
        expect(subject.values(&:id).map(&:to_i)).to match_array(ids)
      end
    end
  end
end
