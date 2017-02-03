class AddSeverityToEventStreams < ActiveRecord::Migration[5.0]
  def change
    add_column :event_streams, :lxca_severity, :string
  end
end
