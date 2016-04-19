class MigrateSecurityProtocolAtributeToEndpoints < ActiveRecord::Migration[5.0]
  class Endpoint < ActiveRecord::Base; end

  class ExtManagementSystem < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    say_with_time("Migrating Security Protocol attribute to Endpoints") do
      ExtManagementSystem.all.each do |ems|
        next if ems.security_protocol.nil?
        endpoint = Endpoint.where(
          :resource_type => "ExtManagementSystem",
          :resource_id   => ems.id,
          :role          => "default").first_or_create

        endpoint.update_attributes!(:security_protocol => ems.security_protocol)
      end
    end
  end

  def down
    say_with_time("Migrating Endpoints Security Protocol attribute to EMS") do
      endpoints = Endpoint.where(
        :role          => "default",
        :resource_type => "ExtManagementSystem",
      )

      endpoints.each do |endpoint|
        next if endpoint.security_protocol.nil?
        ems = ExtManagementSystem.where(:id => endpoint.resource_id).first
        ems.update_attributes!(
          :security_protocol => endpoint.security_protocol)
      end

      Endpoint.delete_all
    end
  end
end
