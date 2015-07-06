require "spec_helper"
require Rails.root.join("db/migrate/20120607195908_rename_table_type_column_to_type_in_vmdb_table.rb")

describe RenameTableTypeColumnToTypeInVmdbTable do
  migration_context :up do
    let(:vmdb_table)      { migration_stub(:VmdbTable) }

    it "Setting type for vmdb_table" do
      vmdb_type    = vmdb_table.create!(:table_type => "vmdb")
      text_type    = vmdb_table.create!(:table_type => "text")
      other_type    = vmdb_table.create!(:table_type => "other")

      migrate

      vmdb_type.reload.type.should    == 'VmdbTableEvm'
      text_type.reload.type.should    == 'VmdbTableText'
      other_type.reload.type.should   be_nil
    end
  end

  migration_context :down do
    let(:vmdb_table)      { migration_stub(:VmdbTable) }

    it "Setting type for vmdb_table" do
      vmdb_type    = vmdb_table.create!(:type => "VmdbTableEvm")
      text_type    = vmdb_table.create!(:type => "VmdbTableText")
      other_type    = vmdb_table.create!(:type => "other")

      migrate

      vmdb_type.reload.table_type.should    == 'vmdb'
      text_type.reload.table_type.should    == 'text'
      other_type.reload.table_type.should   be_nil
    end
  end
end
