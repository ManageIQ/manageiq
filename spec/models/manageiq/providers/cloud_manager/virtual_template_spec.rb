describe ManageIQ::Providers::CloudManager::VirtualTemplate do
  describe '#profile' do
    it 'has a default value of false' do
      vt = FactoryGirl.create(:virtual_template)

      expect(vt.profile).to be_falsey
    end
  end
end
