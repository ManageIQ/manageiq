class AddVmwareRoDatastoresToHostsStorages < ActiveRecord::Migration
  class HostsStorage < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  def up
    add_column :hosts_storages, :read_only, :boolean

    # Find the sequence_start value for our region, if the region is
    # 0 then start at 1
    seq_start_value = ActiveRecord::Base.rails_sequence_start
    seq_start_value = 1 if seq_start_value == 0

    # add_column ... :primary_key was adding ids to all existing rows before
    # the sequence_start could be set, so we have to create the sequence and
    # the primary keys manually
    say_with_time("Add hosts_storages primary_key") do
      # Add an auto-increment sequence to be used by the primary key column
      execute "CREATE SEQUENCE hosts_storages_id_seq START #{seq_start_value}"

      # Add a primary key column named id and use the previously created sequence
      # This will automatically fill in new primary keys for all existing rows
      # in the hosts_storages table
      execute "ALTER TABLE hosts_storages ADD COLUMN id BIGINT PRIMARY KEY "\
              "NOT NULL DEFAULT NEXTVAL('hosts_storages_id_seq')"

      # Now update the sequence to be owned by the pkey column so that when it
      # gets deleted the sequence also is deleted
      execute "ALTER SEQUENCE hosts_storages_id_seq OWNED BY hosts_storages.id"
    end
  end

  def down
    remove_column :hosts_storages, :id
    remove_column :hosts_storages, :read_only
  end
end
