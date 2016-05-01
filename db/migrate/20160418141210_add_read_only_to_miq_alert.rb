class AddReadOnlyToMiqAlert < ActiveRecord::Migration[5.0]
  class MiqAlert < ActiveRecord::Base; end

  MIQ_ALERT_GUIDS = ["9bc0d572-40bd-11de-bd12-005056a170fa", "fc2ae066-44b8-11de-900a-005056a170fa",
                     "8a6d32a8-44b8-11de-900a-005056a170fa", "a9532172-44a5-11de-b543-005056a170fa",
                     "1bb81254-44a6-11de-b543-005056a170fa", "ce2f8846-44a5-11de-b543-005056a170fa",
                     "fb73af80-40bd-11de-bd12-005056a170fa", "e750cdcc-447c-11de-aaba-005056a170fa",
                     "d59185a4-40bc-11de-bd12-005056a170fa", "c2fc477a-44a5-11de-b543-005056a170fa",
                     "fbe4b5ee-447e-11de-aaba-005056a170fa", "3cfbb5ce-40be-11de-bd12-005056a170fa",
                     "731da3b2-40bc-11de-bd12-005056a170fa", "5cd2b880-be53-11de-8d65-000c290de4f9",
                     "8261bf0a-be54-11de-8d65-000c290de4f9", "fdee2784-bf2c-11de-b3b4-000c290de4f9",
                     "9b61fd9e-bf35-11de-b3b4-000c290de4f9", "561d023c-bf36-11de-b3b4-000c290de4f9",
                     "82f853b0-bf36-11de-b3b4-000c290de4f9", "58e8a372-bff9-11de-b3b4-000c290de4f9",
                     "f8b870d0-c23d-11de-a3be-000c290de4f9", "eb88f942-c23e-11de-a3be-000c290de4f9",
                     "196868de-c23f-11de-a3be-000c290de4f9", "4077943a-c240-11de-a3be-000c290de4f9",
                     "89db0be8-c240-11de-a3be-000c290de4f9"].freeze

  def up
    add_column :miq_alerts, :read_only, :boolean

    say_with_time('Add read only parameter to MiqAlert with true for OOTB alerts') do
      MiqAlert.where(:guid => MIQ_ALERT_GUIDS).update(:read_only => true)
    end
  end

  def down
    remove_column :miq_alerts, :read_only
  end
end
