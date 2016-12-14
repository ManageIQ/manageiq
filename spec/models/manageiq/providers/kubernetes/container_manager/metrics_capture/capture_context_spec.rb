describe ManageIQ::Providers::Kubernetes::ContainerManager::MetricsCapture::CaptureContext do
  @node = nil

  before(:each) do
    allow(MiqServer).to receive(:my_zone).and_return("default")
    hostname = 'capture.context.com'
    token = 'theToken'

    @start_time = 1_482_306_073
    @end_time   = 1_482_306_073
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

    VCR.use_cassette("#{described_class.name.underscore}_refresh",
                     :match_requests_on => [:path,]) do # , :record => :new_episodes) do
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
                 "Implementation-Version" => "0.21.5.Final",
                 "Built-From-Git-SHA1"    => "e779588593f13224225356a94f1d8642fbccb30f"}

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
      end
    end
  end
end
