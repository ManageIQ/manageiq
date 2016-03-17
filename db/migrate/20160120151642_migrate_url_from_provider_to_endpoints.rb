class MigrateUrlFromProviderToEndpoints < ActiveRecord::Migration
  class Provider < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  class Endpoint < ActiveRecord::Base; end

  class ExtManagementSystem < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    Endpoint.connection.schema_cache.clear!
    Endpoint.reset_column_information
    say_with_time("Migrating Provider URL attribute to Endpoints") do
      ExtManagementSystem.all.each do |ems|
        next if ems.provider_id.nil?
        provider = Provider.where(:id => ems.provider_id).first
        endpoint = Endpoint.where(
          :resource_type => "Provider",
          :resource_id   => ems.id).first_or_create

        endpoint.update_attributes!(:url => provider.url)
      end
    end
  end

  def down
    say_with_time("Migrating Endpoints URL to Provider") do
      endpoints = Endpoint.where(
        :role          => "default",
        :resource_type => "Provider",
      )

      endpoints.each do |endpoint|
        next if endpoint.url.nil?
        ems = ExtManagementSystem.where(:id => endpoint.resource_id).first
        provider = Provider.where(:id => ems.provider_id).first
        provider.update_attributes!(
          :url => endpoint.url)
      end

      Endpoint.delete_all
    end
  end
end
