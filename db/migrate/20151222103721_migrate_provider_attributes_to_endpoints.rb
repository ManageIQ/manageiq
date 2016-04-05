class MigrateProviderAttributesToEndpoints < ActiveRecord::Migration
  class Provider < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  class Endpoint < ActiveRecord::Base; end

  class ExtManagementSystem < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    say_with_time("Migrating Provider attributes to Endpoints") do
      ExtManagementSystem.all.each do |ems|
        next if ems.provider_id.nil?
        provider = Provider.where(:id => ems.provider_id).first
        endpoint = Endpoint.where(
          :resource_type => "ExtManagementSystem",
          :resource_id   => ems.id).first_or_create

        endpoint.update_attributes!(:verify_ssl => provider.verify_ssl)
      end
    end
  end

  def down
    say_with_time("Migrating Endpoints to Provider attributes") do
      endpoints = Endpoint.where(
        :role          => "default",
        :resource_type => "ExtManagementSystem",
      )

      endpoints.each do |endpoint|
        next if endpoint.verify_ssl.nil?
        ems = ExtManagementSystem.where(:id => endpoint.resource_id).first
        provider = Provider.where(:id => ems.provider_id).first
        provider.update_attributes!(
          :verify_ssl => endpoint.verify_ssl)
      end

      Endpoint.delete_all
    end
  end
end
