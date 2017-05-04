class AddContainerEntityEvents < ActiveRecord::Migration[4.2]
  def change
    add_column  :event_streams, :container_id, :bigint
    add_column  :event_streams, :container_name, :string
  end
end
