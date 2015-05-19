require "spec_helper"
require Rails.root.join("db/migrate/20150405141637_remove_port_config_from_container_service.rb")

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
      pconfig.protocol.should    == "TCP"
      pconfig.port.should        == 1111
      pconfig.target_port.should == "2222" # container_port:integer turns into target_port:string

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
      service.protocol.should       == "TCP"
      service.port.should           == 1111
      service.container_port.should == 2222
    end
  end
end
