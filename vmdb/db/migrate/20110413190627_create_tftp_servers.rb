class CreateTftpServers < ActiveRecord::Migration
  def self.up
    create_table :tftp_servers do |t|
      t.string      :name
      t.string      :uri_prefix
      t.string      :uri

      t.timestamps
    end
  end

  def self.down
    drop_table :tftp_servers
  end
end
