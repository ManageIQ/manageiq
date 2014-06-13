class AddDrbUriToMiqServer < ActiveRecord::Migration
  def self.up
    add_column :miq_servers, :drb_uri, :string
  end

  def self.down
    remove_column :miq_servers, :drb_uri
  end
end
