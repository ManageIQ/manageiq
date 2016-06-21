describe ManageIQ::Providers::Kubernetes::ContainerManager::MetricsCapture::CaptureContext do
  @node = nil

  before(:each) do
    allow(MiqServer).to receive(:my_zone).and_return("default")
    hostname = 'yzamir-centos7-1.example.com'
    token = 'TheToken'
    @start_time = 1_468_235_843
    @end_time   = 1_568_235_843
    @interval   = 20

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

    VCR.use_cassette("#{described_class.name.underscore}_refresh") do # , :record => :new_episodes) do
      EmsRefresh.refresh(@ems)
      @node = @ems.container_nodes.first
      pod = @ems.container_groups.first
      container = @ems.containers.first

      @targets = [['node', @node], ['pod', pod], ['container', container]]
    end if @node.nil?
  end

  it "will read hawkular status" do
    VCR.use_cassette("#{described_class.name.underscore}_status") do # , :record => :new_episodes) do
      context = ManageIQ::Providers::Kubernetes::ContainerManager::MetricsCapture::CaptureContext.new(
        @node, @start_time, @end_time, @interval
      )

      metrics = {"MetricsService"         => "STARTED",
                 "Implementation-Version" => "0.17.0-SNAPSHOT",
                 "Built-From-Git-SHA1"    => "56ede2a1bf69da749b4e7092b4b8ed7a399e8f2f"}

      data = context.hawkular_client.http_get('/status')

      expect(data).to eq(metrics)
    end
  end

  it "will read hawkular metrics" do
    @targets.each do |target_name, target|
      VCR.use_cassette("#{described_class.name.underscore}_#{target_name}_metrics") do # , :record => :new_episodes) do
        context = ManageIQ::Providers::Kubernetes::ContainerManager::MetricsCapture::CaptureContext.new(
          target, @start_time, @end_time, @interval
        )

        data = context.collect_metrics

        expect(data).to be_a_kind_of(Array)
        expect(data.length).to be > 10
        expect(data[1]['start']).to be
      end
    end
  end
end
