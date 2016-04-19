class AddReadOnlyToMiqAlert < ActiveRecord::Migration[5.0]
  def up
    add_column :miq_alerts, :read_only, :boolean
    say_with_time('Add read only parameter to MiqAlert with true for OOTB alerts') do
      guids = YAML.load_file(Rails.root.join("db/fixtures/miq_alerts.yml")).map { |h| h["guid"] || h[:guid] }
      MiqAlert.where(:guid => guids).update(:read_only => true)
    end
  end

  def down
    remove_column :miq_alerts, :read_only
  end
end
