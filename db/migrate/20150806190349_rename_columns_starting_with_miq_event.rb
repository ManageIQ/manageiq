class RenameColumnsStartingWithMiqEvent < ActiveRecord::Migration
  def change
    rename_column :miq_policy_contents, :miq_event_id, :miq_event_definition_id
    rename_column :policy_events, :miq_event_id, :miq_event_definition_id
    rename_column :policy_events, :miq_event_description, :miq_event_definition_description
  end
end
