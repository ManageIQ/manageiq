describe Authentication do
  it ".encrypted_columns" do
    expect(described_class.encrypted_columns).to include('password', 'auth_key')
  end

  context "with miq events seeded" do
    before(:each) do
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
    let(:pwd_encrypt) { MiqPassword.encrypt(pwd_plain) }
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
end
