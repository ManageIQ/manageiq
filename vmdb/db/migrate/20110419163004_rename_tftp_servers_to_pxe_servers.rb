class RenameTftpServersToPxeServers < ActiveRecord::Migration
  def self.up
    rename_table :tftp_servers, :pxe_servers
  end

  def self.down
    rename_table :pxe_servers, :tftp_servers
  end
end
