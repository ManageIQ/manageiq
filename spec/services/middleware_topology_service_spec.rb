describe MiddlewareTopologyService do
  let(:middleware_topology_service) { described_class.new(nil) }
  let(:long_id_0) { "/t;28026b36-8fe4-4332-84c8-524e173a68bf/f;e055631d-c1a5-4a2d-926a-1dfdcff5137c/r;Local~~" }
  let(:long_id_1) { "#{long_id_0}/r;Local~%2Fdeployment=hawkular-command-gateway-war.war" }
  let(:long_id_2) { "#{long_id_0}/r;Local~%2Fdeployment=hawkular-wildfly-agent-download.war" }
  let(:long_id_3) { "#{long_id_0}/r;Local~%2Fsubsystem%3Ddatasources%2Fdata-source%3DExampleDS" }
  let(:long_id_4) { "Local~/deployment=hawkular-wildfly-agent-download.war" }
  let(:long_id_5) { "Local~/deployment=hawkular-command-gateway-war.war" }
  let(:long_id_6) { "Local~/subsystem=datasources/data-source=ExampleDS" }
  let(:long_id_7) { "Local~/subsystem=messaging-activemq/server=default/jms-topic=HawkularMetricData" }

  describe "#build_kinds" do
    it "creates the expected number of entity types" do
      supported_kinds = [:MiddlewareServer, :MiddlewareDeployment, :MiddlewareDatasource, :MiddlewareManager, :Vm,
                         :MiddlewareDomain, :MiddlewareServerGroup, :MiddlewareMessaging]
      expect(middleware_topology_service.build_kinds.keys).to match_array(supported_kinds)
    end
  end

  describe "#build_topology" do
    subject { middleware_topology_service.build_topology }

    let(:ems_hawkular) { FactoryGirl.create(:ems_hawkular) }
    let(:mw_server) do
      FactoryGirl.create(:hawkular_middleware_server,
                         :name                  => 'Local',
                         :feed                  => '70c798a0-6985-4f8a-a525-012d8d28e8a3',
                         :ems_ref               => long_id_0,
                         :nativeid              => 'Local~~',
                         :ext_management_system => ems_hawkular)
    end

    it "topology contains the expected structure and content" do
      allow(middleware_topology_service).to receive(:retrieve_providers).and_return([ems_hawkular])

      mw_deployment1 = MiddlewareDeployment.create(:ext_management_system => ems_hawkular,
                                                   :middleware_server     => mw_server,
                                                   :ems_ref               => long_id_2,
                                                   :name                  => "hawkular-wildfly-agent-download.war",
                                                   :nativeid              => long_id_4)

      mw_deployment2 = MiddlewareDeployment.create(:ext_management_system => ems_hawkular,
                                                   :middleware_server     => mw_server,
                                                   :ems_ref               => long_id_1,
                                                   :name                  => "hawkular-command-gateway-war.war",
                                                   :nativeid              => long_id_5)

      mw_datasource = MiddlewareDatasource.create(:ext_management_system => ems_hawkular,
                                                  :middleware_server     => mw_server,
                                                  :ems_ref               => long_id_3,
                                                  :name                  => "ExampleDS",
                                                  :nativeid              => long_id_6)

      mw_messaging = MiddlewareMessaging.create(:ext_management_system => ems_hawkular,
                                                :middleware_server     => mw_server,
                                                :ems_ref               => long_id_2,
                                                :name                  => "JMS Topic [HawkularMetricData]",
                                                :nativeid              => long_id_7)

      expect(subject[:items]).to eq(
        "MiddlewareManager" + ems_hawkular.compressed_id.to_s      => {:name         => ems_hawkular.name,
                                                                       :status       => "Unknown",
                                                                       :kind         => "MiddlewareManager",
                                                                       :display_kind => "Hawkular",
                                                                       :miq_id       => ems_hawkular.id,
                                                                       :icon         => "vendor-hawkular"},

        "MiddlewareServer" + mw_server.compressed_id.to_s          => {:name         => mw_server.name,
                                                                       :status       => "Unknown",
                                                                       :kind         => "MiddlewareServer",
                                                                       :display_kind => "MiddlewareServer",
                                                                       :miq_id       => mw_server.id,
                                                                       :icon         => "vendor-wildfly"},

        "MiddlewareDeployment" + mw_deployment1.compressed_id.to_s => {:name         => mw_deployment1.name,
                                                                       :status       => "Unknown",
                                                                       :kind         => "MiddlewareDeployment",
                                                                       :display_kind => "MiddlewareDeploymentWar",
                                                                       :miq_id       => mw_deployment1.id},

        "MiddlewareDeployment" + mw_deployment2.compressed_id.to_s => {:name         => mw_deployment2.name,
                                                                       :status       => "Unknown",
                                                                       :kind         => "MiddlewareDeployment",
                                                                       :display_kind => "MiddlewareDeploymentWar",
                                                                       :miq_id       => mw_deployment2.id},

        "MiddlewareDatasource" + mw_datasource.compressed_id.to_s  => {:name         => mw_datasource.name,
                                                                       :status       => "Unknown",
                                                                       :kind         => "MiddlewareDatasource",
                                                                       :display_kind => "MiddlewareDatasource",
                                                                       :miq_id       => mw_datasource.id},

        "MiddlewareMessaging" + mw_messaging.compressed_id.to_s    => {:name         => mw_messaging.name,
                                                                       :status       => "Unknown",
                                                                       :kind         => "MiddlewareMessaging",
                                                                       :display_kind => "MiddlewareMessaging",
                                                                       :miq_id       => mw_messaging.id},

      )

      expect(subject[:relations].size).to eq(5)
      expect(subject[:relations]).to include(
        {:source => "MiddlewareManager" + ems_hawkular.compressed_id.to_s,
         :target => "MiddlewareServer" + mw_server.compressed_id.to_s},
        {:source => "MiddlewareServer" + mw_server.compressed_id.to_s,
         :target => "MiddlewareDeployment" + mw_deployment1.compressed_id.to_s},
        {:source => "MiddlewareServer" + mw_server.compressed_id.to_s,
         :target => "MiddlewareDeployment" + mw_deployment2.compressed_id.to_s},
        {:source => "MiddlewareServer" + mw_server.compressed_id.to_s,
         :target => "MiddlewareDatasource" + mw_datasource.compressed_id.to_s},
        {:source => "MiddlewareServer" + mw_server.compressed_id.to_s,
         :target => "MiddlewareMessaging" + mw_messaging.compressed_id.to_s}
      )
    end
  end
end
