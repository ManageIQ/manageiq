class AddFileDepotIdToMiqSchedule < ActiveRecord::Migration
  class MiqSchedule < ActiveRecord::Base
    def file_depot
      return @file_depot if defined?(@file_depot)
      @file_depot = FileDepot.where(:id => file_depot_id).first
    end
  end

  class FileDepot < ActiveRecord::Base
    self.inheritance_column = :_type_disabled

    def resource
      return @resource if defined?(@resource)
      @resource = MiqSchedule.where(:id => resource_id).first
    end
  end

  def up
    add_column :miq_schedules, :file_depot_id, :bigint

    say_with_time "Updating Schedules with file depots" do
      FileDepot.where(:resource_type => "MiqSchedule").each { |depot| depot.resource.update_attributes(:file_depot_id => depot.id) if depot.resource }
    end

    remove_column :file_depots, :resource_id
    remove_column :file_depots, :resource_type
  end

  def down
    add_column :file_depots, :resource_id,   :bigint
    add_column :file_depots, :resource_type, :string

    say_with_time "Updating Schedules with file depots" do
      MiqSchedule.all.each { |schedule| schedule.file_depot.update_attributes(:resource_type => "MiqSchedule", :resource_id => schedule.id) if schedule.file_depot }
    end

    remove_column :miq_schedules, :file_depot_id
  end
end
