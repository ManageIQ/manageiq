require "spec_helper"

describe Authentication do
  context "with miq events seeded" do
    before(:each) do
      MiqRegion.seed
      MiqEvent.seed
    end

    it "should create the authentication events and event sets" do
      events = %w(ems_auth_changed ems_auth_valid ems_auth_invalid ems_auth_unreachable ems_auth_incomplete ems_auth_error
                  host_auth_changed host_auth_valid host_auth_invalid host_auth_unreachable host_auth_incomplete host_auth_error)
      events.each { |event| MiqEvent.exists?(:name => event).should be_true }
      MiqEventSet.exists?(:name => 'auth_validation').should be_true
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
end
