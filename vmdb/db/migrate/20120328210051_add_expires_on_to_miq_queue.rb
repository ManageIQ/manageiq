class AddExpiresOnToMiqQueue < ActiveRecord::Migration
  class MiqQueue < ActiveRecord::Base
    self.table_name = "miq_queue"
    include ReservedMixin
    include MigrationStubHelper # NOTE: Must be included after other mixins
  end

  def self.up
    add_column :miq_queue, :expires_on, :timestamp

    say_with_time("Migrate data from reserved table") do
      queue_ids = Reserve.where(:resource_type => "MiqQueue").uniq.pluck(:resource_id)
      MiqQueue.where(:id => queue_ids).includes(:reserved_rec).find_each do |q|
        q.reserved_hash_migrate(:expires_on)
      end
    end
  end

  def self.down
    remove_column :miq_queue, :expires_on
  end
end
