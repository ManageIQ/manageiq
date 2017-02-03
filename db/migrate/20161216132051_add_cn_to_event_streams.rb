class AddCnToEventStreams < ActiveRecord::Migration[5.0]
  def change
    add_column :event_streams, :lxca_cn, :string
  end
end
