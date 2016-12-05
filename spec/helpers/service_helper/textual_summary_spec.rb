describe ServiceHelper::TextualSummary do
  context ".textual_orchestration_stack" do
    before do
      login_as @user = FactoryGirl.create(:user)
    end

    subject { textual_orchestration_stack }
    it 'contains the link to the associated stack' do
      @os_cloud  = FactoryGirl.create(:orchestration_stack_cloud, :name => "cloudstack1")
      @record = FactoryGirl.create(:service)
      allow(@record).to receive(:orchestration_stack).and_return(@os_cloud)
      expect(textual_orchestration_stack[:link]).to eq("/orchestration_stack/show/#{@os_cloud.id}")
    end

    it 'contains the link to the associated stack' do
      @os_infra  = FactoryGirl.create(:orchestration_stack_openstack_infra, :name => "infrastack1")
      @record = FactoryGirl.create(:service)
      allow(@record).to receive(:orchestration_stack).and_return(@os_infra)
      expect(textual_orchestration_stack[:link]).to eq("/orchestration_stack/show/#{@os_infra.id}")
    end
  end
end
