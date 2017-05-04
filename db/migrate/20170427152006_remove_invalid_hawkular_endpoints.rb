class RemoveInvalidHawkularEndpoints < ActiveRecord::Migration[5.0]
  class ExtManagementSystem < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class Endpoint < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class Authentication < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  def up
    ems_container_ids = ExtManagementSystem.where(
      :type => %w(ManageIQ::Providers::Openshift::ContainerManager ManageIQ::Providers::Kubernetes::ContainerManager)
    ).pluck(:id)
    delete_ids = Endpoint.where(
      :resource_type => 'ExtManagementSystem',
      :resource_id   => ems_container_ids,
      :role          => "hawkular",
      :hostname      => ["", nil],
    ).pluck(:resource_id)

    unless delete_ids.empty?
      say_with_time("Removing invalid endpoint and authentication for ems ids [#{delete_ids}]") do
        Endpoint.where(
          :resource_type => 'ExtManagementSystem',
          :resource_id   => delete_ids,
          :role          => "hawkular",
        ).destroy_all
        Authentication.where(
          :authtype      => "hawkular",
          :resource_type => 'ExtManagementSystem',
          :resource_id   => delete_ids
        ).destroy_all
      end
    end
  end

  def down
    ems_containers_by_id = ExtManagementSystem.where(
      :type => %w(ManageIQ::Providers::Openshift::ContainerManager ManageIQ::Providers::Kubernetes::ContainerManager)
    ).map { |ems| [ems.id, ems] }.to_h

    ems_container_ids = ems_containers_by_id.keys
    ems_with_hawkular = Endpoint.where(
      :resource_type => 'ExtManagementSystem',
      :resource_id   => ems_container_ids,
      :role          => "hawkular",
    ).pluck(:resource_id)
    create_ids = ems_container_ids - ems_with_hawkular

    unless create_ids.empty?
      create_ids.each do |ems_id|
        say_with_time("Recreating invalid endpoint and authentication for [#{ems_id}]") do
          Endpoint.create!(
            :role              => "hawkular",
            :hostname          => "",
            :port              => 443,
            :resource_type     => "ExtManagementSystem",
            :resource_id       => ems_id,
            :verify_ssl        => 1,
            :security_protocol => "ssl-with-validation",
          )
          default_auth = Authentication.find_by(
            :authtype      => 'bearer',
            :resource_type => "ExtManagementSystem",
            :resource_id   => ems_id
          )
          Authentication.create!(
            :name          => "#{ems_containers_by_id[ems_id].type} #{ems_containers_by_id[ems_id].name}",
            :authtype      => "hawkular",
            :resource_type => "ExtManagementSystem",
            :resource_id   => ems_id,
            :type          => "AuthToken",
            :auth_key      => default_auth.auth_key
          )
        end
      end
    end
  end
end
