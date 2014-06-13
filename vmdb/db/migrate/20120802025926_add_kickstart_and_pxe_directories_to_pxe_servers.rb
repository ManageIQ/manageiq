class AddKickstartAndPxeDirectoriesToPxeServers < ActiveRecord::Migration
  def change
    add_column :pxe_servers, :pxe_directory,       :string
    add_column :pxe_servers, :kickstart_directory, :string
  end
end
