class AddLastReplicationIdAndCountToMiqDatabase < ActiveRecord::Migration
  class MiqDatabase < ActiveRecord::Base
    include ReservedMixin
    include MigrationStubHelper # NOTE: Must be included after other mixins
  end

  def up
    add_column :miq_databases, :last_replication_count, :bigint
    add_column :miq_databases, :last_replication_id,    :bigint

    say_with_time("Migrate data from reserved table") do
      MiqDatabase.includes(:reserved_rec).each do |db|
        db.reserved_hash_migrate(:last_replication_count, :last_replication_id)
      end
    end
  end

  def down
    remove_column :miq_databases, :last_replication_count
    remove_column :miq_databases, :last_replication_id
  end
end
