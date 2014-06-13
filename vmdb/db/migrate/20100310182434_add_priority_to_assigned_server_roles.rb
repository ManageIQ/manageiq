class AddPriorityToAssignedServerRoles < ActiveRecord::Migration
  class AssignedServerRole < ActiveRecord::Base
    serialize :reserved
  end

  def self.up
    add_column    :assigned_server_roles, :priority, :integer

    say_with_time("Migrate data from reserved column or set default") do
      AssignedServerRole.all.each do |rec|
        res = rec.reserved
        if res.kind_of?(Hash)
          rec.priority = res.delete(:priority).to_i
          rec.reserved = res.empty? ? nil : res
          rec.save
        else
          rec.update_attribute(:priority, 2)
        end
      end
    end
  end

  def self.down
    say_with_time("Migrate data to reserved column") do
      AssignedServerRole.all.each do |rec|
        rec.reserved ||= {}
        rec.reserved[:priority] = rec.priority
        rec.save
      end
    end

    remove_column :assigned_server_roles, :priority
  end
end
