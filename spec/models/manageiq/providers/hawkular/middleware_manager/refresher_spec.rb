describe ManageIQ::Providers::Hawkular::MiddlewareManager::Refresher do
  before do
    allow(MiqServer).to receive(:my_zone).and_return("default")
    auth = AuthToken.new(:name => "test", :auth_key => "valid-token", :userid => "jdoe", :password => "password")
    @ems_hawkular = FactoryGirl.create(:ems_hawkular,
                                       :hostname        => 'localhost',
                                       :port            => 8080,
                                       :authentications => [auth])
  end

  it "will perform a full refresh on localhost" do
    VCR.use_cassette(described_class.name.underscore.to_s,
                     :allow_unused_http_interactions => true,
                     :decode_compressed_response     => true) do # , :record => :new_episodes) do
      EmsRefresh.refresh(@ems_hawkular)
    end

    @ems_hawkular.reload

    expect(@ems_hawkular.middleware_domains.count).to be > 0
    domain = @ems_hawkular.middleware_domains.first
    expect(domain.middleware_server_groups.count).to be > 0
    expect(@ems_hawkular.middleware_servers.count).to be > 0
    expect(@ems_hawkular.middleware_deployments.count).to be > 0
    expect(@ems_hawkular.middleware_datasources.count).to be > 0
    expect(@ems_hawkular.middleware_messagings.count).to be > 0
    expect(@ems_hawkular.middleware_deployments.first).to have_attributes(:status => 'Enabled')
    assert_specific_datasource('Local~/subsystem=datasources/data-source=ExampleDS')
    assert_specific_datasource('Local~/host=master/server=server-one/subsystem=datasources/data-source=ExampleDS')
    assert_specific_server_group(domain)
    assert_specific_domain_server
    assert_specific_domain
  end

  def assert_specific_datasource(nativeid)
    datasource = @ems_hawkular.middleware_datasources.find_by_nativeid(nativeid)
    expect(datasource).to have_attributes(
      :name     => 'Datasource [ExampleDS]',
      :nativeid => nativeid
    )
    expect(datasource.properties).not_to be_nil
    expect(datasource.properties).to have_attributes(
      'Driver Name' => 'h2',
      'JNDI Name'   => 'java:jboss/datasources/ExampleDS',
      'Enabled'     => 'true'
    )
  end

  def assert_specific_domain
    domain = @ems_hawkular.middleware_domains.find_by_name('master')
    expect(domain).to have_attributes(
      :name     => 'master',
      :nativeid => 'Local~/host=master',
    )
    expect(domain.properties).not_to be_nil
    expect(domain.properties).to have_attributes(
      'Running Mode'         => 'NORMAL',
      'Host State'           => 'running',
      'Is Domain Controller' => 'true',
    )
  end

  def assert_specific_server_group(domain)
    server_group = domain.middleware_server_groups.find_by_name('main-server-group')
    expect(server_group).to have_attributes(
      :name     => 'main-server-group',
      :nativeid => 'Local~/server-group=main-server-group',
      :profile  => 'full',
    )
    expect(server_group.properties).not_to be_nil
  end

  def assert_specific_domain_server
    server = @ems_hawkular.middleware_servers.find_by_name('server-three')
    expect(server).to have_attributes(
      :name     => 'server-three',
      :nativeid => 'Local~/host=master/server=server-three',
      :product  => 'not yet available',
      :hostname => 'not yet available',
    )
    expect(server.properties).not_to be_nil
  end
end
