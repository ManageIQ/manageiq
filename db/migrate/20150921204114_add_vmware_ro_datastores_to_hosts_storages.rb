class AddVmwareRoDatastoresToHostsStorages < ActiveRecord::Migration
  class HostsStorage < ActiveRecord::Base; end

  def up
    rename_table :hosts_storages, :host_storages
    add_column :host_storages, :read_only, :boolean

    # Find the sequence_start value for our region, if the region is
    # 0 then start at 1
    seq_start_value = ArRegion.anonymous_class_with_ar_region.rails_sequence_start
    seq_start_value = 1 if seq_start_value == 0

    # add_column ... :primary_key was adding ids to all existing rows before
    # the sequence_start could be set, so we have to create the sequence and
    # the primary keys manually
    say_with_time("Add host_storages primary_key") do
      # Add an auto-increment sequence to be used by the primary key column
      execute "CREATE SEQUENCE host_storages_id_seq START #{seq_start_value}"

      # Add a primary key column named id and use the previously created sequence
      # This will automatically fill in new primary keys for all existing rows
      # in the host_storages table
      execute "ALTER TABLE host_storages ADD COLUMN id BIGINT PRIMARY KEY "\
              "NOT NULL DEFAULT NEXTVAL('host_storages_id_seq')"

      # Now update the sequence to be owned by the pkey column so that when it
      # gets deleted the sequence also is deleted
      execute "ALTER SEQUENCE host_storages_id_seq OWNED BY host_storages.id"
    end
  end

  def down
    remove_column :host_storages, :id
    remove_column :host_storages, :read_only
    rename_table :host_storages, :hosts_storages
  end
end
