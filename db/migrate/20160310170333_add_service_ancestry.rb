class AddServiceAncestry < ActiveRecord::Migration[5.0]
  class Service < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def update_service_parent(parent)
    ancestry = [parent.ancestry.presence, parent.id].compact.join("/") if parent
    Service.where(:service_id => parent.try(:id)).each do |svc|
      svc.update_attributes(:ancestry => ancestry) if ancestry
      update_service_parent(svc)
    end
  end

  def up
    add_column :services, :ancestry, :string
    add_index :services, :ancestry

    say_with_time("Converting Services from service_id ancestry") do
      update_service_parent(nil)
    end

    remove_column :services, :service_id
  end

  def down
    add_column :services, :service_id, :bigint
    add_index :services, :service_id

    say_with_time("Converting Services from ancestry to service_id") do
      Service.all.each do |service|
        parent_service_id = service.ancestry.split("/").last.to_i if service.ancestry.present?
        service.update_attributes(:service_id => parent_service_id)
      end
    end

    remove_column :services, :ancestry
  end
end
