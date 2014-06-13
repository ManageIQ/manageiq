class AddRhnMirror < ActiveRecord::Migration
  def change
    add_column :miq_servers, :rhn_mirror, :boolean
  end
end
