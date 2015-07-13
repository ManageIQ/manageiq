class AddColsToPxeServers < ActiveRecord::Migration
  def self.up
    add_column    :pxe_servers, :last_refresh_on, :datetime
    add_column    :pxe_servers, :visibility,      :text
  end

  def self.down
    remove_column  :pxe_servers, :last_refresh_on
    remove_column  :pxe_servers, :visibility
  end
end
