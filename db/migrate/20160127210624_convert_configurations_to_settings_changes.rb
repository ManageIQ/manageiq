class ConvertConfigurationsToSettingsChanges < ActiveRecord::Migration
  class Configuration < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
    serialize :settings
  end

  class SettingsChange < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
    serialize :value
  end

  def up
    say_with_time("Migrating configuration changes") do
      deltas = Configuration.all.flat_map { |f| full_to_deltas(f) }
      deltas.each { |d| SettingsChange.create!(d) }
    end
  end

  private

  def full_to_deltas(full_config)
    deltas = Vmdb::Settings::HashDiffer.changes(TEMPLATES[full_config.typ], full_config.settings)
    deltas.each do |d|
      d.merge!(
        :name          => full_config.typ,
        :resource_type => "MiqServer",
        :resource_id   => full_config.miq_server_id,
        :created_at    => full_config.created_on,
        :updated_at    => full_config.updated_on,
      )
    end
  end

  # TODO: Replace the vmdb key with a hardcoded Hash
  # TODO: Add the rest of the convertable config types
  TEMPLATES = {
    "vmdb" => YAML.load_file(Rails.root.join("config/vmdb.tmpl.yml"))
  }
end
