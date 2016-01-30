describe LdapServer do
  before(:each) do
    @zone        = FactoryGirl.create(:zone)
    @ldap_region = FactoryGirl.create(:ldap_region, :zone => @zone)
    @ldap_domain = FactoryGirl.create(:ldap_domain, :ldap_region => @ldap_region)
    @ldap_server = FactoryGirl.create(:ldap_server, :ldap_domain => @ldap_domain)
  end

  context "#verify_credentials" do
    it "when LdapDomain#connect returns nil" do
      allow_any_instance_of(LdapDomain).to receive(:connect).with(@ldap_server).and_return(nil)
      expect { @ldap_server.verify_credentials }.to raise_error(MiqException::Error, "Authentication failed")
    end

    it "when LdapDomain#connect returns connection handle" do
      handle = double("handle")
      allow_any_instance_of(LdapDomain).to receive(:connect).with(@ldap_server).and_return(handle)
      expect(@ldap_server.verify_credentials).to eq(handle)
    end

    it "when LdapDomain#connect returns an error" do
      msg = "Invalid socket"
      err = SocketError.new(msg)
      allow_any_instance_of(LdapDomain).to receive(:connect).with(@ldap_server).and_raise(err)
      expect { @ldap_server.verify_credentials }.to raise_error(MiqException::Error, msg)
    end
  end
end
