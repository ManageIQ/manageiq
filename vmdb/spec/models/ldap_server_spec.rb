require "spec_helper"

describe LdapServer do
  before(:each) do
    @zone        = FactoryGirl.create(:zone)
    @ldap_region = FactoryGirl.create(:ldap_region, :zone => @zone)
    @ldap_domain = FactoryGirl.create(:ldap_domain, :ldap_region => @ldap_region)
    @ldap_server = FactoryGirl.create(:ldap_server, :ldap_domain => @ldap_domain)
  end

  context "#verify_credentials" do

    it "when LdapDomain#connect returns nil" do
      LdapDomain.any_instance.stub(:connect).with(@ldap_server).and_return(nil)
      lambda {@ldap_server.verify_credentials}.should raise_error(MiqException::Error, "Authentication failed")
    end

    it "when LdapDomain#connect returns connection handle" do
      handle = double("handle")
      LdapDomain.any_instance.stub(:connect).with(@ldap_server).and_return(handle)
      @ldap_server.verify_credentials.should == handle
    end

    it "when LdapDomain#connect returns an error" do
      msg = "Invalid socket"
      err = SocketError.new(msg)
      LdapDomain.any_instance.stub(:connect).with(@ldap_server).and_raise(err)
      lambda {@ldap_server.verify_credentials}.should raise_error(MiqException::Error, msg)
    end

  end

end
