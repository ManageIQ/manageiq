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
    expect(@ldap_server.ldap_domain).to eq(@ldap_domain)
    expect(@ldap_user.ldap_domain).to eq(@ldap_domain)
    expect(@ldap_group.ldap_domain).to eq(@ldap_domain)

    expect(@ldap_domain.ldap_region).to eq(@ldap_region)
    expect(@ldap_region.zone).to eq(@zone)

    expect(@zone.ldap_regions.count).to eq(1)
    expect(@ldap_region.ldap_domains.count).to eq(1)
    expect(@ldap_domain.ldap_servers.count).to eq(1)
    expect(@ldap_domain.ldap_users.count).to eq(1)
    expect(@ldap_domain.ldap_groups.count).to eq(1)
  end
end
