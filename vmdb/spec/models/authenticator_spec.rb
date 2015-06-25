require "spec_helper"

describe Authenticator do
  describe '.for' do
    it "instantiates the matching class" do
      expect(Authenticator.for(:mode => 'database')).to be_a(Authenticator::Database)
      expect(Authenticator.for(:mode => 'ldap')).to be_a(Authenticator::Ldap)
      expect(Authenticator.for(:mode => 'ldaps')).to be_a(Authenticator::Ldap)
      expect(Authenticator.for(:mode => 'amazon')).to be_a(Authenticator::Amazon)
      expect(Authenticator.for(:mode => 'httpd')).to be_a(Authenticator::Httpd)
    end

    it "always uses local DB for admin" do
      expect(Authenticator.for({:mode => 'database'}, 'admin')).to be_a(Authenticator::Database)
      expect(Authenticator.for({:mode => 'ldap'}, 'admin')).to be_a(Authenticator::Database)
      expect(Authenticator.for({:mode => 'httpd'}, 'admin')).to be_a(Authenticator::Database)
    end
  end
end
