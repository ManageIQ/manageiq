describe ManageIQ::Providers::Kubernetes::ContainerManager::MetricsCapture::CaptureContext do
  @node = nil

  before(:each) do
    allow(MiqServer).to receive(:my_zone).and_return("default")
    hostname = 'capture.context.com'
    token = 'theToken'

    @ems = FactoryGirl.create(
      :ems_openshift,
      :name                      => 'OpenShiftProvider',
      :connection_configurations => [{:endpoint       => {:role       => :default,
                                                          :hostname   => hostname,
                                                          :port       => "8443",
                                                          :verify_ssl => false},
                                      :authentication => {:role     => :bearer,
                                                          :auth_key => token,
                                                          :userid   => "_"}},
                                     {:endpoint       => {:role       => :hawkular,
                                                          :hostname   => hostname,
                                                          :port       => "443",
                                                          :verify_ssl => false},
                                      :authentication => {:role     => :hawkular,
                                                          :auth_key => token,
                                                          :userid   => "_"}}]
    )

    VCR.use_cassette("#{described_class.name.underscore}_refresh",
                     :match_requests_on => [:path,]) do # , :record => :new_episodes) do
      EmsRefresh.refresh(@ems)
      @ems.reload

      @node = @ems.container_nodes.find_by(:name => "capture.context.com")
      pod = @ems.container_groups.find_by(:name => "docker-registry-1-51q71")
      container = pod.containers.find_by(:name => "registry")

      @targets = [['node', @node], ['pod', pod], ['container', container]]
    end if @node.nil?
  end

  it "will read hawkular status" do
    start_time = Time.parse("2017-06-22 18:35:42 UTC").utc
    end_time   = nil
    interval   = nil

    VCR.use_cassette("#{described_class.name.underscore}_status") do # , :record => :new_episodes) do
      context = ManageIQ::Providers::Kubernetes::ContainerManager::MetricsCapture::CaptureContext.new(
        @node, start_time, end_time, interval
      )

      metrics = {"MetricsService"         => "STARTED",
                 "Cassandra"              => "up",
                 "Implementation-Version" => "0.26.1.Final",
                 "Built-From-Git-SHA1"    => "45b148c834ed62018f153c23187b4436ae4208fe"}

      data = context.hawkular_client.http_get('/status')

      expect(data).to eq(metrics)
    end
  end

  it "will read hawkular metrics" do
    start_time = Time.parse("2017-06-22 18:40:42 UTC").utc
    end_time   = nil
    interval   = 20

    @targets.each do |target_name, target|
      VCR.use_cassette("#{described_class.name.underscore}_#{target_name}_metrics") do # , :record => :new_episodes) do
        context = ManageIQ::Providers::Kubernetes::ContainerManager::MetricsCapture::CaptureContext.new(
          target, start_time, end_time, interval
        )

        data = context.collect_metrics

        expect(data).to be_a_kind_of(Array)
      end
    end
  end

  it "will read only specific timespan hawkular metrics" do
    start_time = Time.parse("2017-06-22 18:35:42 UTC").utc
    end_time   = Time.parse("2017-06-22 18:40:42 UTC").utc
    interval   = 20

    @targets.each do |target_name, target|
      VCR.use_cassette("#{described_class.name.underscore}_#{target_name}_timespan") do # , :record => :new_episodes) do
        context = ManageIQ::Providers::Kubernetes::ContainerManager::MetricsCapture::CaptureContext.new(
          target, start_time, end_time, interval
        )

        data = context.collect_metrics

        expect(data.count).to eq(9)
      end
    end
  end
end
