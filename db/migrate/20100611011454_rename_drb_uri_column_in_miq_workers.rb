class RenameDrbUriColumnInMiqWorkers < ActiveRecord::Migration
  def self.up
    rename_column :miq_workers, :drb_uri, :uri
  end

  def self.down
    rename_column :miq_workers, :uri, :drb_uri
  end
end
