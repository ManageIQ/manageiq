class RenameKickstartDirectoryToCustomizationDirectory < ActiveRecord::Migration
  def up
    rename_column :pxe_servers, :kickstart_directory, :customization_directory
  end

  def down
    rename_column :pxe_servers, :customization_directory, :kickstart_directory
  end
end
