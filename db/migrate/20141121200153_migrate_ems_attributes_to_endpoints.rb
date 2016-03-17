class MigrateEmsAttributesToEndpoints < ActiveRecord::Migration
  class ExtManagementSystem < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  class Endpoint < ActiveRecord::Base; end

  def up
    say_with_time("Migrating EMS attributes to endpoints") do
      ExtManagementSystem.all.each do |e|
        Endpoint.create!(
          :role          => "default",
          :ipaddress     => e.ipaddress,
          :hostname      => e.hostname,
          :port          => e.port && e.port.to_i,
          :resource_type => "ExtManagementSystem",
          :resource_id   => e.id,
        )
      end
    end
  end

  def down
    say_with_time("Migrating endpoints to EMS attributes") do
      endpoints = Endpoint.where(
        :role          => "default",
        :resource_type => "ExtManagementSystem",
      )

      endpoints.each do |endpoint|
        ems = ExtManagementSystem.where(:id => endpoint.resource_id).first

        ems.update_attributes!(
          :ipaddress => endpoint.ipaddress,
          :hostname  => endpoint.hostname,
          :port      => endpoint.port && endpoint.port.to_s
        )
      end

      Endpoint.delete_all
    end
  end
end
