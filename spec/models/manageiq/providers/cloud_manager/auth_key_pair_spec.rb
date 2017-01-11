describe ManageIQ::Providers::CloudManager::AuthKeyPair do
  let(:ems) { FactoryGirl.create(:ems_cloud) }

  context 'create and delete actions' do
    it "has methods" do
      expect(subject.class.respond_to? :create_key_pair).to be true
      expect(subject.respond_to? :delete_key_pair).to be true
    end

    # TODO(maufart): do we have any special approach to test module methods separately?
    it 'forces implement methods' do
      expect { subject.class.create_key_pair ems.id, {} }.to raise_error NotImplementedError
      expect { subject.delete_key_pair }.to raise_error NotImplementedError
    end
  end

  context 'validations' do
    it "has methods" do
      expect(subject.class.respond_to? :validate_create_key_pair).to be true
      expect(subject.respond_to? :validate_delete_key_pair).to be true
    end

    it "fails by default" do
      expect(subject.class.validate_create_key_pair ems, {}).to eq(
        :available => false,
        :message   => "Create KeyPair Operation is not available for ManageIQ::Providers::CloudManager::AuthKeyPair.")
      expect(subject.validate_delete_key_pair).to eq(
        :available => false,
        :message   => "Delete KeyPair Operation is not available for ManageIQ::Providers::CloudManager::AuthKeyPair.")
    end
  end
end
