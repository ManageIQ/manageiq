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

    expect(@ems_hawkular.middleware_servers.count).to be > 0
    expect(@ems_hawkular.middleware_deployments.count).to be > 0
    expect(@ems_hawkular.middleware_datasources.count).to be > 0
    assert_specific_datasource
  end

  def assert_specific_datasource
    datasource = @ems_hawkular.middleware_datasources.find_by_name('ExampleDS')
    expect(datasource).to have_attributes(
      :name     => 'ExampleDS',
      :nativeid => 'Local~/subsystem=datasources/data-source=ExampleDS'
    )
    expect(datasource.properties).not_to be_nil
    expect(datasource.properties).to have_attributes(
      'Driver Name' => 'h2',
      'JNDI Name'   => 'java:jboss/datasources/ExampleDS',
      'Enabled'     => 'true'
    )
  end
end
