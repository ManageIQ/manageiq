class AddServiceAncestry < ActiveRecord::Migration[5.0]
  class Service < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def update_service_parent(parent)
    Service.where(:service_id => parent.try(:id)).each do |svc|
      ancestry = [parent.try(:ancestry), parent.try(:id)].compact.join("/")
      svc.update_attributes(:ancestry => ancestry) if parent
      update_service_parent(svc)
    end
  end

  def up
    add_column :services, :ancestry, :string
    add_index :services, :ancestry

    Service.connection.schema_cache.clear!
    Service.reset_column_information

    say_with_time("Converting Services from service_id ancestry") do
      update_service_parent(nil)
    end

    remove_column :services, :service_id
  end

  def down
    add_column :services, :service_id, :bigint
    add_index :services, :service_id

    Service.connection.schema_cache.clear!
    Service.reset_column_information

    say_with_time("Converting Services from ancestry to service_id") do
      Service.all.each do |service|
        service.update_attributes(:service_id => service.ancestry.split("/").last.try(:to_i)) if service.ancestry
      end
    end

    remove_column :services, :ancestry
  end
end
