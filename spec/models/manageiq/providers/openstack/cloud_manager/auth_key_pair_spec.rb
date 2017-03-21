describe ManageIQ::Providers::Openstack::CloudManager::AuthKeyPair do
  let(:ems) { FactoryGirl.create(:ems_openstack_with_authentication) }
  let(:key_pair_attributes) { {:name => "key1", :public_key => "AAA...B"} }

  describe 'key pair create and delete' do
    it 'creates new key pair in nova' do
      service = double
      key_pairs = double
      allow(ExtManagementSystem).to receive(:find).with(ems.id).and_return(ems)
      allow(ems).to receive(:connect).with(:service => 'Compute').and_return(service)
      allow(service).to receive(:key_pairs).and_return(key_pairs)
      allow(key_pairs).to receive(:create).with(key_pair_attributes).and_return(
        FactoryGirl.create :auth_key_pair_openstack)
      subject.class.create_key_pair(ems.id, key_pair_attributes)
    end

    it 'deletes existing key pair from nova' do
      service = double
      subject.name = 'key1'
      subject.resource = ems
      allow(ems).to receive(:connect).with(:service => 'Compute').and_return(service)
      allow(service).to receive(:delete_key_pair).with('key1')
      subject.delete_key_pair
    end
  end

  describe 'validations' do
    it 'fails create with invalid parameters' do
      expect(subject.class.validate_create_key_pair(nil)).to eq(
        :available => false,
        :message   => 'The Keypair is not connected to an active Provider')
    end

    it 'pass create with valid parameters' do
      expect(subject.class.validate_create_key_pair(ems)).to eq(
        :available => true,
        :message   => nil)
    end
  end
end
