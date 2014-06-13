require "spec_helper"

describe LdapDomain do
  before(:each) do
    @zone        = FactoryGirl.create(:zone)

    @ldap_region = FactoryGirl.create(:ldap_region, :zone => @zone)
    @ldap_domain = FactoryGirl.create(:ldap_domain, :ldap_region => @ldap_region)
    @ldap_server = FactoryGirl.create(:ldap_server, :ldap_domain => @ldap_domain)
    @ldap_user   = FactoryGirl.create(:ldap_user,   :ldap_domain => @ldap_domain)
    @ldap_group  = FactoryGirl.create(:ldap_group,  :ldap_domain => @ldap_domain)
  end

  it "should create proper AR relationships" do
    @ldap_server.ldap_domain.should == @ldap_domain
    @ldap_user.ldap_domain.should   == @ldap_domain
    @ldap_group.ldap_domain.should  == @ldap_domain

    @ldap_domain.ldap_region.should == @ldap_region
    @ldap_region.zone.should        == @zone

    @zone.ldap_regions.count.should  == 1
    @ldap_region.ldap_domains.count.should == 1
    @ldap_domain.ldap_servers.count.should == 1
    @ldap_domain.ldap_users.count.should   == 1
    @ldap_domain.ldap_groups.count.should  == 1
  end
end
