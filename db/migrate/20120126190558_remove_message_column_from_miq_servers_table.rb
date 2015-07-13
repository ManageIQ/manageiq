class RemoveMessageColumnFromMiqServersTable < ActiveRecord::Migration
  def up
    remove_column :miq_servers, :message
  end

  def down
    add_column    :miq_servers, :message,        :string
  end
end
