describe ManageIQ::Providers::Redhat::InfraManager::Refresh::Refresher do
  let(:ems) { FactoryGirl.build(:ems_redhat) }
  describe 'chooses the right refresher strategy' do
    context "when v4 api" do
      before(:each) do
        allow(ems).to receive(:highest_supported_api_version).and_return(4)
      end

      it 'returns the api4 refresher' do
        expect(ems.refresher).to eq(ManageIQ::Providers::Redhat::InfraManager::Refresh::Strategies::Api4)
      end
    end

    context "when v3 api" do
      before(:each) do
        allow(ems).to receive(:highest_supported_api_version).and_return(3)
      end

      it 'returns the api3 refresher' do
        expect(ems.refresher).to eq(ManageIQ::Providers::Redhat::InfraManager::Refresh::Strategies::Api3)
      end
    end
  end
end
