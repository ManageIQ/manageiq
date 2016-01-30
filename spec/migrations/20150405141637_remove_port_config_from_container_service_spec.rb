require_migration

describe RemovePortConfigFromContainerService do
  let(:container_service_stub)             { migration_stub(:ContainerService) }
  let(:container_service_port_config_stub) { migration_stub(:ContainerServicePortConfig) }

  migration_context :up do
    it 'Moves port, protocol and host(target)-port to container_service_port_config table' do
      service = container_service_stub.create!(:ems_ref        => "test_ref",
                                               :name           => "test_service",
                                               :protocol       => "TCP",
                                               :port           => 1111,
                                               :container_port => 2222)
      migrate
      pconfig = container_service_port_config_stub.where(:container_service_id => service.id).first
      expect(pconfig.protocol).to eq("TCP")
      expect(pconfig.port).to eq(1111)
      expect(pconfig.target_port).to eq("2222") # container_port:integer turns into target_port:string
    end
  end

  migration_context :down do
    it 'Moves port, protocol and target_port back to container_service table' do
      service = container_service_stub.create!(:ems_ref => "test_ref",
                                               :name    => "test_service")
      container_service_port_config_stub.create!(:container_service_id => service.id,
                                                 :protocol             => "TCP",
                                                 :port                 => 1111,
                                                 :target_port          => "2222")
      migrate
      service.reload
      expect(service.protocol).to eq("TCP")
      expect(service.port).to eq(1111)
      expect(service.container_port).to eq(2222)
    end
  end
end
