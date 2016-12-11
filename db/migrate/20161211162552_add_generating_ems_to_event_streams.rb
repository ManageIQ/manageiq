class AddGeneratingEmsToEventStreams < ActiveRecord::Migration[5.0]
  def change
    add_reference :event_streams, :generating_ems, :type => :bigint
  end
end
