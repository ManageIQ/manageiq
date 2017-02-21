describe ManageIQ::Providers::Kubernetes::ContainerManager::LongTermAverages do
  @node = nil

  before(:each) do
    allow(MiqServer).to receive(:my_zone).and_return("default")
    hostname = 'hawkular-lta.example.com'
    token = 'secret'

    @ems = FactoryGirl.create(
      :ems_openshift,
      :name                      => 'OpenShiftProvider',
      :connection_configurations => [{:endpoint       => {:role     => :default,
                                                          :hostname => hostname,
                                                          :port     => "8443"},
                                      :authentication => {:role     => :bearer,
                                                          :auth_key => token,
                                                          :userid   => "_"}},
                                     {:endpoint       => {:role     => :hawkular,
                                                          :hostname => hostname,
                                                          :port     => "443"},
                                      :authentication => {:role     => :hawkular,
                                                          :auth_key => token,
                                                          :userid   => "_"}}]
    )
    @ems.tag_with(["/live_reports/hawkular_datasource"], :ns => "/managed")

    if @node.nil?
      VCR.use_cassette("#{described_class.name.underscore}_refresh", :match_requests_on => [:path,]) do # , :record => :new_episodes) do
        EmsRefresh.refresh(@ems)
        @node = @ems.container_nodes.first
      end
    end
  end

  it "will parse hawkular_datasource tag" do
    expect(@node.vpor_live?).to be_truthy
  end

  it "will read hawkular long term averages" do
    VCR.use_cassette("#{described_class.name.underscore}_lt_averages") do # , :record => :new_episodes) do
      end_date = Time.parse("2017-01-21 00:00:00 +0000").utc
      data = ManageIQ::Providers::Kubernetes::ContainerManager::LongTermAverages.get_averages_over_time_period(
        @node,
        :end_date => end_date
      )

      expect(data).to be_a_kind_of(Hash)
      expect(data[:avg]).to be_a_kind_of(Hash)
      expect(data[:dev]).to be_a_kind_of(Hash)
      expect(data[:dev][:max_cpu_usage_rate_average]).to be_a_kind_of(Numeric)
    end
  end
end
