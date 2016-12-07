describe ServiceHelper::TextualSummary do
  describe ".textual_orchestration_stack" do
    let(:os_cloud) { FactoryGirl.create(:orchestration_stack_cloud, :name => "cloudstack1") }
    let(:os_infra) { FactoryGirl.create(:orchestration_stack_openstack_infra, :name => "infrastack1") }

    before do
      login_as FactoryGirl.create(:user)
    end

    subject { textual_orchestration_stack }
    it 'contains the link to the associated cloud stack' do
      @record = FactoryGirl.create(:service)
      allow(@record).to receive(:orchestration_stack).and_return(os_cloud)
      expect(textual_orchestration_stack).to eq(os_cloud)
    end

    it 'contains the link to the associated infra stack' do
      @record = FactoryGirl.create(:service)
      allow(@record).to receive(:orchestration_stack).and_return(os_infra)
      expect(textual_orchestration_stack).to eq(os_infra)
    end

    it 'contains no link for an invalid stack' do
      os_infra.id = nil
      @record = FactoryGirl.create(:service)
      allow(@record).to receive(:orchestration_stack).and_return(os_infra)
      expect(textual_orchestration_stack[:link]).to be_nil
    end
  end
end
