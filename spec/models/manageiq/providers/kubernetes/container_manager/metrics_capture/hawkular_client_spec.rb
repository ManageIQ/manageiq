describe ManageIQ::Providers::Kubernetes::ContainerManager::MetricsCapture::HawkularClient do
  before(:each) do
    allow(MiqServer).to receive(:my_zone).and_return("default")
    hostname = 'hawkular.example.com'
    token = 'the_token'

    @ems = FactoryGirl.create(
      :ems_openshift,
      :name                      => 'OpenShiftProvider',
      :connection_configurations => [{:endpoint       => {:role     => :default,
                                                          :hostname => hostname,
                                                          :port     => "8443"},
                                      :authentication => {:role     => :bearer,
                                                          :auth_key => token}},
                                     {:endpoint       => {:role     => :hawkular,
                                                          :hostname => hostname,
                                                          :port     => "443"},
                                      :authentication => {:role     => :hawkular,
                                                          :auth_key => token}}]
    )
  end

  it "will try to connect to server" do
    VCR.use_cassette("#{described_class.name.underscore}_try_connect") do # , :record => :new_episodes) do
      client = ManageIQ::Providers::Kubernetes::ContainerManager::MetricsCapture::HawkularClient.new(@ems)

      data = client.hawkular_try_connect
      expect(data).to eq(true)
    end
  end

  it "will try to query metric gauges definitions" do
    VCR.use_cassette("#{described_class.name.underscore}_gauges_query") do # , :record => :new_episodes) do
      client = ManageIQ::Providers::Kubernetes::ContainerManager::MetricsCapture::HawkularClient.new(@ems, 'default')

      data = client.gauges.query(:type => 'pod')
      expect(data[0].tenant_id).to eq('default')
      expect(data[0].tags['pod_name']).to be
    end
  end

  it "will try to query metric gauges ad-hoc data" do
    VCR.use_cassette("#{described_class.name.underscore}_get_data") do # , :record => :new_episodes) do
      client = ManageIQ::Providers::Kubernetes::ContainerManager::MetricsCapture::HawkularClient.new(@ems, '_system')

      data = client.gauges.get_data('machine/hawkular.example.com/cpu/limit',
                                    :limit => 5,
                                    :order => 'DESC')
      expect(data[0]['timestamp']).to be
      expect(data[0]['value']).to be
    end
  end
end
