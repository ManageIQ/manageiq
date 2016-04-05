class RemovePortConfigFromContainerService < ActiveRecord::Migration
  class ContainerService < ActiveRecord::Base
    has_many :container_service_port_configs,
             :class_name => "RemovePortConfigFromContainerService::ContainerServicePortConfig"
  end

  class ContainerServicePortConfig < ActiveRecord::Base
    belongs_to :container_service,
               :class_name => "RemovePortConfigFromContainerService::ContainerService"
  end

  def up
    create_table :container_service_port_configs do |t|
      t.string     :ems_ref
      t.string     :name
      t.integer    :port
      t.string     :target_port
      t.string     :protocol
      t.belongs_to :container_service, :type => :bigint
    end

    say_with_time("Moving container_service port records to container_service_port_config table") do
      ContainerService.all.each do |service|
        ContainerServicePortConfig.create!(
          :ems_ref              => "#{service.ems_ref}_#{service.port}_#{service.container_port}",
          :port                 => service.port,
          :protocol             => service.protocol,
          :target_port          => service.container_port,
          :container_service_id => service.id
        )
      end
    end

    remove_column :container_services, :port
    remove_column :container_services, :protocol
    remove_column :container_services, :container_port
  end

  def down
    add_column :container_services, :port, :integer
    add_column :container_services, :protocol, :string
    add_column :container_services, :container_port, :integer

    say_with_time("Moving container service port config records back to container service") do
      ContainerService.all.each do |service|
        port_config = service.container_service_port_configs.first
        service.update_attributes!(:port           => port_config.port,
                                   :protocol       => port_config.protocol,
                                   :container_port => port_config.target_port)
      end
    end

    drop_table :container_service_port_configs
  end
end
