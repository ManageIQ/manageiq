describe Authentication do
  describe ".encrypted_columns" do
    it "returns the encrypted columns" do
      expected = %w(password password_encrypted auth_key auth_key_encrypted service_account service_account_encrypted)
      expect(described_class.encrypted_columns).to match_array(expected)
    end
  end

  context "with miq events seeded" do
    before(:each) do
      MiqEventDefinitionSet.seed
      MiqEventDefinition.seed
    end

    it "should create the authentication events and event sets" do
      events = %w(ems_auth_changed ems_auth_valid ems_auth_invalid ems_auth_unreachable ems_auth_incomplete ems_auth_error
                  host_auth_changed host_auth_valid host_auth_invalid host_auth_unreachable host_auth_incomplete host_auth_error)
      events.each { |event| expect(MiqEventDefinition.exists?(:name => event)).to be_truthy }
      expect(MiqEventDefinitionSet.exists?(:name => 'auth_validation')).to be_truthy
    end
  end

  context "with an authentication" do
    let(:pwd_plain) { "smartvm" }
    let(:auth) { FactoryGirl.create(:authentication, :password => pwd_plain) }

    it "should return decrypted password" do
      expect(auth.password).to eq(pwd_plain)
    end

    it "should store encrypted password" do
      expect(Authentication.where(:password => pwd_plain).count).to eq(0)
      expect(auth.reload.password).to eq(pwd_plain)
    end
  end

  context "#retryable_status?" do
    it "works" do
      expect(described_class.new(:status => 'valid').retryable_status?).to       be_falsy
      expect(described_class.new(:status => 'none').retryable_status?).to        be_falsy
      expect(described_class.new(:status => 'incomplete').retryable_status?).to  be_falsy
      expect(described_class.new(:status => 'error').retryable_status?).to       be_truthy
      expect(described_class.new(:status => 'unreachable').retryable_status?).to be_truthy
      expect(described_class.new(:status => 'invalid').retryable_status?).to     be_falsy
    end

    it "is case insensitive" do
      expect(described_class.new(:status => 'Error').retryable_status?).to be_truthy
    end
  end

  context '.class_from_request_data' do
    it 'raises an error if it is not an authentication type' do
      expect do
        described_class.class_from_request_data('type' => 'ServiceTemplate')
      end.to raise_error(RuntimeError, 'Must be an Authentication type')
    end

    it 'returns self if no type is specified' do
      expect(described_class.class_from_request_data({})).to eq(described_class)
    end

    it 'returns self if Authentication is specified' do
      expect(described_class.class_from_request_data('type' => 'Authentication')).to eq(described_class)
    end

    it 'returns the specified type' do
      data = {
        'type' => 'ManageIQ::Providers::EmbeddedAnsible::AutomationManager::MachineCredential'
      }
      expect(described_class.class_from_request_data(data))
        .to eq(ManageIQ::Providers::EmbeddedAnsible::AutomationManager::MachineCredential)
    end
  end
end
