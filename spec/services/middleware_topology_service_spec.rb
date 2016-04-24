describe MiddlewareTopologyService do
  let(:middleware_topology_service) { described_class.new(nil) }
  let(:long_id_1) { "/t;28026b36-8fe4-4332-84c8-524e173a68bf/f;e055631d-c1a5-4a2d-926a-1dfdcff5137c/r;Local~~/r;Local~%2Fdeployment=hawkular-command-gateway-war.war" }
  let(:long_id_2) { "/t;28026b36-8fe4-4332-84c8-524e173a68bf/f;e055631d-c1a5-4a2d-926a-1dfdcff5137c/r;Local~~/r;Local~%2Fdeployment=hawkular-wildfly-agent-download.war" }
  let(:long_id_3) { "/t;28026b36-8fe4-4332-84c8-524e173a68bf/f;e055631d-c1a5-4a2d-926a-1dfdcff5137c/r;Local~~" }

  describe "#build_kinds" do
    it "creates the expected number of entity types" do
      expect(middleware_topology_service.build_kinds.keys).to match_array([:MiddlewareServer, :MiddlewareDeployment, :MiddlewareManager])
    end
  end

  describe "#build_topology" do
    subject { middleware_topology_service.build_topology }

    let(:ems_hawkular) { FactoryGirl.create(:ems_hawkular) }
    let(:middleware_server) { FactoryGirl.create(:hawkular_middleware_server,
                                                 :name                  => 'Local',
                                                 :feed                  => 'cda13e2a-e206-4e87-8bca-8cfdd5aea484',
                                                 :ems_ref               => long_id_3,
                                                 :nativeid              => 'Local~~',
                                                 :ext_management_system => ems_hawkular)
    }

    it "topology contains the expected structure and content" do
      allow(middleware_topology_service).to receive(:retrieve_providers).and_return([ems_hawkular])

      middleware_deployment1 = MiddlewareDeployment.create(:ext_management_system => ems_hawkular, :middleware_server => middleware_server,
                                                           :ems_ref               => long_id_2,
                                                           :name                  => "hawkular-wildfly-agent-download.war",
                                                           :nativeid              => "Local~/deployment=hawkular-wildfly-agent-download.war")

      middleware_deployment2 = MiddlewareDeployment.create(:ext_management_system => ems_hawkular, :middleware_server => middleware_server,
                                                           :ems_ref               => long_id_1,
                                                           :name                  => "hawkular-command-gateway-war.war",
                                                           :nativeid              => "Local~/deployment=hawkular-command-gateway-war.war")
      expect(subject[:items]).to eq(
                                     ems_hawkular.id.to_s           => {:name         => ems_hawkular.name,
                                                                        :status       => "Unknown",
                                                                        :kind         => "MiddlewareManager",
                                                                        :display_kind => "Hawkular",
                                                                        :miq_id       => ems_hawkular.id,
                                                                        :icon         => "vendor-hawkular",
                                                                        :id           => ems_hawkular.id.to_s},

                                     middleware_server.ems_ref      => {:name         => middleware_server.name,
                                                                        :status       => "Unknown",
                                                                        :kind         => "MiddlewareServer",
                                                                        :display_kind => "MiddlewareServer",
                                                                        :miq_id       => middleware_server.id,
                                                                        :icon         => "vendor-wildfly",
                                                                        :id           => middleware_server.nativeid},

                                     middleware_deployment1.ems_ref => {:name         => middleware_deployment1.name,
                                                                        :status       => "Unknown",
                                                                        :kind         => "MiddlewareDeployment",
                                                                        :display_kind => "MiddlewareDeployment",
                                                                        :miq_id       => middleware_deployment1.id,
                                                                        :icon         => "middleware_deployment_war",
                                                                        :id           => middleware_deployment1.nativeid},

                                     middleware_deployment2.ems_ref => {:name         => middleware_deployment2.name,
                                                                        :status       => "Unknown",
                                                                        :kind         => "MiddlewareDeployment",
                                                                        :display_kind => "MiddlewareDeployment",
                                                                        :miq_id       => middleware_deployment2.id,
                                                                        :icon         => "middleware_deployment_war",
                                                                        :id           => middleware_deployment2.nativeid},

      )

      expect(subject[:relations].size).to eq(3)
      expect(subject[:relations]).to include(
                                              {:source => ems_hawkular.id.to_s, :target      => middleware_server.ems_ref},
                                              {:source => middleware_server.ems_ref, :target => middleware_deployment1.ems_ref},
                                              {:source => middleware_server.ems_ref, :target => middleware_deployment2.ems_ref}
      )
    end
  end
end
