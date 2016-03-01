describe ContainerTopologyService do

  let(:container_topology_service) { described_class.new(nil) }
  let(:long_id) { "3572afee-3a41-11e5-a79a-001a4a231290_ruby-helloworld-database_openshift\n/mysql-55-centos7:latest" }

  describe "#build_kinds" do
    it "creates the expected number of entity types" do
      allow(container_topology_service).to receive(:retrieve_providers).and_return([FactoryGirl.create(:ems_kubernetes)])
      expect(container_topology_service.build_kinds.keys).to match_array([:Container, :Host, :ContainerManager, :ContainerNode, :ContainerGroup, :ContainerReplicator, :ContainerRoute, :ContainerService, :Vm])
    end
  end

  describe "#build_link" do
    it "creates link between source to target" do
      expect(container_topology_service.build_link("95e49048-3e00-11e5-a0d2-18037327aaeb", "96c35f65-3e00-11e5-a0d2-18037327aaeb")).to eq(:source => "95e49048-3e00-11e5-a0d2-18037327aaeb", :target => "96c35f65-3e00-11e5-a0d2-18037327aaeb")
    end
  end

  describe "#build_topology" do
    subject { container_topology_service.build_topology }

    it "topology contains only the expected keys" do
      expect(subject.keys).to match_array([:items, :kinds, :relations])
    end

    let(:container) { Container.create(:name => "ruby-example", :ems_ref => long_id, :state => 'running') }
    let(:container_condition) { ContainerCondition.create(:name => 'Ready', :status => 'True') }
    let(:container_def) { ContainerDefinition.create(:name => "ruby-example", :ems_ref => 'b6976f84-5184-11e5-950e-001a4a231290_ruby-helloworld_172.30.194.30:5000/test/origin-ruby-sample@sha256:0cd076c9beedb3b1f5cf3ba43da6b749038ae03f5886b10438556e36ec2a0dd9', :container => container) }
    let(:container_node) { ContainerNode.create(:ext_management_system => ems_kube, :name => "127.0.0.1", :ems_ref => "905c90ba-3e00-11e5-a0d2-18037327aaeb", :container_conditions => [container_condition], :lives_on => vm_rhev) }
    let(:ems_kube) { FactoryGirl.create(:ems_kubernetes_with_authentication_err) }
    let(:ems_openshift) { FactoryGirl.create(:ems_openshift) }
    let(:ems_rhev) { FactoryGirl.create(:ems_redhat) }
    let(:vm_rhev) { FactoryGirl.create(:vm_redhat, :uid_ems => "558d9a08-7b13-11e5-8546-129aa6621998", :ext_management_system => ems_rhev) }

    it "provider has unknown status when no authentication exists" do
      allow(container_topology_service).to receive(:retrieve_providers).and_return([ems_openshift])
      expect(subject[:items]).to eq(
        "ContainerManager" + ems_openshift.compressed_id.to_s         => {:name         => ems_openshift.name,
                                                                          :status       => "Unknown",
                                                                          :kind         => "ContainerManager",
                                                                          :display_kind => "Openshift",
                                                                          :miq_id       => ems_openshift.id})

    end

    it "topology contains the expected structure and content" do
      # vm and host test cross provider correlation to infra provider
      hardware = FactoryGirl.create(:hardware, :cpu_sockets => 2, :cpu_cores_per_socket => 4, :cpu_total_cores => 8)
      host = FactoryGirl.create(:host_redhat,
                                :uid_ems => "abcd9a08-7b13-11e5-8546-129aa6621999",
                                :ext_management_system => ems_rhev,
                                :hardware => hardware)
      vm_rhev.update_attributes(:host => host, :raw_power_state => "up")

      allow(container_topology_service).to receive(:retrieve_providers).and_return([ems_kube])
      container_replicator = ContainerReplicator.create(:ext_management_system => ems_kube,
                                                        :ems_ref               => "8f8ca74c-3a41-11e5-a79a-001a4a231290",
                                                        :name                  => "replicator1")
      container_route = ContainerRoute.create(:ext_management_system => ems_kube,
                                              :ems_ref               => "ab5za74c-3a41-11e5-a79a-001a4a231290",
                                              :name                  => "route-edge")
      container_group = ContainerGroup.create(:ext_management_system => ems_kube,
                                              :container_node        => container_node, :container_replicator => container_replicator,
                                              :name                  => "myPod", :ems_ref => "96c35ccd-3e00-11e5-a0d2-18037327aaeb",
                                              :phase                 => "Running", :container_definitions => [container_def])
      container_service = ContainerService.create(:ext_management_system => ems_kube, :container_groups => [container_group],
                                                  :ems_ref               => "95e49048-3e00-11e5-a0d2-18037327aaeb",
                                                  :name                  => "service1", :container_routes => [container_route])
      expect(subject[:items]).to eq(
        "ContainerManager" + ems_kube.compressed_id.to_s                => {:name         => ems_kube.name,
                                                                            :status       => "Error",
                                                                            :kind         => "ContainerManager",
                                                                            :display_kind => "Kubernetes",
                                                                            :miq_id       => ems_kube.id},

        "ContainerNode" + container_node.compressed_id.to_s             => {:name         => container_node.name,
                                                                            :status       => "Ready",
                                                                            :kind         => "ContainerNode",
                                                                            :display_kind => "Node",
                                                                            :miq_id       => container_node.id},

        "ContainerReplicator" + container_replicator.compressed_id.to_s => {:name         => container_replicator.name,
                                                                            :status       => "OK",
                                                                            :kind         => "ContainerReplicator",
                                                                            :display_kind => "Replicator",
                                                                            :miq_id       => container_replicator.id},

        "ContainerService" + container_service.compressed_id.to_s       => {:name         => container_service.name,
                                                                            :status       => "Unknown",
                                                                            :kind         => "ContainerService",
                                                                            :display_kind => "Service",
                                                                            :miq_id       => container_service.id},

        "ContainerGroup" + container_group.compressed_id.to_s           => {:name         => container_group.name,
                                                                            :status       => "Running",
                                                                            :kind         => "ContainerGroup",
                                                                            :display_kind => "Pod",
                                                                            :miq_id       => container_group.id},

        "ContainerRoute" + container_route.compressed_id.to_s           => {:name         => container_route.name,
                                                                            :status       => "Unknown",
                                                                            :kind         => "ContainerRoute",
                                                                            :display_kind => "Route",
                                                                            :miq_id       => container_route.id},

        "Container" + container.compressed_id.to_s                      => {:name         => container.name,
                                                                            :status       => "Running",
                                                                            :kind         => "Container",
                                                                            :display_kind => "Container",
                                                                            :miq_id       => container.id},

        "Vm" + vm_rhev.compressed_id.to_s                               => {:name         => vm_rhev.name,
                                                                            :status       => "On",
                                                                            :kind         => "Vm",
                                                                            :display_kind => "VM",
                                                                            :miq_id       => vm_rhev.id,
                                                                            :provider     => ems_rhev.name},

        "Host" + host.compressed_id.to_s                                => {:name         => host.name,
                                                                            :status       => "On",
                                                                            :kind         => "Host",
                                                                            :display_kind => "Host",
                                                                            :miq_id       => host.id,
                                                                            :provider     => ems_rhev.name}
      )

      expect(subject[:relations].size).to eq(8)
      expect(subject[:relations]).to include(
        {:source => "ContainerReplicator" + container_replicator.compressed_id.to_s, :target => "ContainerGroup" + container_group.compressed_id.to_s},
        {:source => "ContainerService" + container_service.compressed_id.to_s, :target => "ContainerRoute" + container_route.compressed_id.to_s},
        # cross provider correlations
        {:source => "Vm" + vm_rhev.compressed_id.to_s, :target => "Host" + host.compressed_id.to_s},
        {:source => "ContainerNode" + container_node.compressed_id.to_s, :target => "Vm" + vm_rhev.compressed_id.to_s},
        {:source => "ContainerNode" + container_node.compressed_id.to_s, :target => "ContainerGroup" + container_group.compressed_id.to_s},
        {:source => "ContainerManager" + ems_kube.compressed_id.to_s, :target => "ContainerNode" + container_node.compressed_id.to_s},
        {:source => "ContainerGroup" + container_group.compressed_id.to_s, :target => "Container" + container.compressed_id.to_s},
        {:source => "ContainerService" + container_service.compressed_id.to_s, :target => "ContainerGroup" + container_group.compressed_id.to_s}
      )
    end

    it "topology contains the expected structure when vm is off" do
      # vm and host test cross provider correlation to infra provider
      vm_rhev.update_attributes(:raw_power_state => "down")
      allow(container_topology_service).to receive(:retrieve_providers).and_return([ems_kube])

      container_group = ContainerGroup.create(:ext_management_system => ems_kube, :container_node => container_node,
                                              :name => "myPod", :ems_ref => "96c35ccd-3e00-11e5-a0d2-18037327aaeb",
                                              :phase => "Running", :container_definitions => [container_def])
      container_service = ContainerService.create(:ext_management_system => ems_kube, :container_groups => [container_group],
                                                  :ems_ref => "95e49048-3e00-11e5-a0d2-18037327aaeb",
                                                  :name => "service1")
      allow(container_topology_service).to receive(:entities).and_return([[container_node], [container_service]])

      expect(subject[:items]).to eq(
        "ContainerNode" + container_node.compressed_id.to_s       => {:name         => container_node.name,
                                                                      :status       => "Ready",
                                                                      :kind         => "ContainerNode",
                                                                      :display_kind => "Node",
                                                                      :miq_id       => container_node.id},

        "ContainerService" + container_service.compressed_id.to_s => {:name         => container_service.name,
                                                                      :status       => "Unknown",
                                                                      :kind         => "ContainerService",
                                                                      :display_kind => "Service",
                                                                      :miq_id       => container_service.id},

        "ContainerGroup" + container_group.compressed_id.to_s     => {:name         => container_group.name,
                                                                      :status       => "Running",
                                                                      :kind         => "ContainerGroup",
                                                                      :display_kind => "Pod",
                                                                      :miq_id       => container_group.id},

        "Container" + container.compressed_id.to_s                => {:name         => container.name,
                                                                      :status       => "Running",
                                                                      :kind         => "Container",
                                                                      :display_kind => "Container",
                                                                      :miq_id       => container.id},

        "Vm" + vm_rhev.compressed_id.to_s                         => {:name         => vm_rhev.name,
                                                                      :status       => "Off",
                                                                      :kind         => "Vm",
                                                                      :display_kind => "VM",
                                                                      :miq_id       => vm_rhev.id,
                                                                      :provider     => ems_rhev.name},

        "ContainerManager" + ems_kube.compressed_id.to_s          => {:name         => ems_kube.name,
                                                                      :status       => "Error",
                                                                      :kind         => "ContainerManager",
                                                                      :display_kind => "Kubernetes",
                                                                      :miq_id       => ems_kube.id}
      )

      expect(subject[:relations].size).to eq(5)
      expect(subject[:relations]).to include(
        {:source => "ContainerService" + container_service.compressed_id.to_s, :target => "ContainerGroup" + container_group.compressed_id.to_s},
        # cross provider correlation
        {:source => "ContainerNode" + container_node.compressed_id.to_s, :target => "Vm" + vm_rhev.compressed_id.to_s},
      )
    end
  end
end
