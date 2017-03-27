describe ManageIQ::Providers::Redhat::InfraManager::Refresh::Parse::ParserBuilder do
  let(:ems) { FactoryGirl.build(:ems_redhat) }
  let(:use_ovirt_engine_sdk) { true }
  let(:options) { {} }
  subject { described_class.new(ems, options).build }
  describe 'chooses the right parsing strategy' do
    before do
      stub_settings_merge(:ems => { :ems_redhat => { :use_ovirt_engine_sdk => use_ovirt_engine_sdk } })
    end

    context "when v4 api" do
      before(:each) do
        allow(ems).to receive(:highest_supported_api_version).and_return(4)
      end

      it 'returns the api4 parser' do
        expect(subject).to eq(ManageIQ::Providers::Redhat::InfraManager::Refresh::Parse::Strategies::Api4)
      end

      context "when use_ovirt_engine_sdk setting is turned to false" do
        let(:use_ovirt_engine_sdk) { false }
        it 'returns the api3 parser' do
          expect(subject).to eq(ManageIQ::Providers::Redhat::InfraManager::Refresh::Parse::Strategies::Api3)
        end
      end

      context "forced version 3" do
        let(:options) { { :force_version => 3  } }

        it 'returns the api3 parser' do
          expect(subject).to eq(ManageIQ::Providers::Redhat::InfraManager::Refresh::Parse::Strategies::Api3)
        end
      end

    end

    context "when v3 api" do
      before(:each) do
        allow(ems).to receive(:highest_supported_api_version).and_return(3)
      end

      it 'returns the api3 parser' do
        expect(subject).to eq(ManageIQ::Providers::Redhat::InfraManager::Refresh::Parse::Strategies::Api3)
      end

      context "forced version 4" do
        let(:options) { { :force_version => 4  } }

        it 'returns the api4 parser' do
          expect(subject).to eq(ManageIQ::Providers::Redhat::InfraManager::Refresh::Parse::Strategies::Api4)
        end
      end
    end
  end
end
