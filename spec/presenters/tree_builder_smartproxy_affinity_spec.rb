describe TreeBuilderSmartproxyAffinity do
  context 'TreeBuilderSmartproxyAffinity' do
    before do
      role = MiqUserRole.find_by_name("EvmRole-operator")
      @group = FactoryGirl.create(:miq_group, :miq_user_role => role, :description => "SmartProxy Affinity Group")
      login_as FactoryGirl.create(:user, :userid => 'smartproxy_affinity_wilma', :miq_groups => [@group])
      
    end
    it 'TODO' do
      expect(true).to eq(true)
    end
  end
end