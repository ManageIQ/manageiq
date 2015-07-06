class RenameTableTypeColumnToTypeInVmdbTable < ActiveRecord::Migration
  class VmdbTable < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    say_with_time("Migrate vmdb_tables table_type to STI") do
      VmdbTable.update_all("table_type = case when table_type='vmdb' then 'VmdbTableEvm' when table_type='text' then 'VmdbTableText' end")
    end

    rename_column :vmdb_tables, :table_type, :type
  end

  def down
    rename_column :vmdb_tables, :type, :table_type

    say_with_time("Migrate vmdb_tables table_type from STI") do
      VmdbTable.update_all("table_type = case when table_type='VmdbTableEvm' then 'vmdb' when table_type='VmdbTableText' then 'text' end")
    end
  end
end
