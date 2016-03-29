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
      deltas = Configuration.where(:typ => TEMPLATES.keys).all.flat_map { |f| full_to_deltas(f) }
      deltas.each { |d| SettingsChange.create!(d) }
    end
  end

  private

  def full_to_deltas(full_config)
    deltas = Vmdb::Settings::HashDiffer.changes(TEMPLATES[full_config.typ], full_config.settings.deep_symbolize_keys)
    deltas.each do |d|
      d.merge!(
        :resource_type => "MiqServer",
        :resource_id   => full_config.miq_server_id,
        :created_at    => full_config.created_on,
        :updated_at    => full_config.updated_on,
      )
      d[:key] = "/#{full_config.typ}#{d[:key]}" unless full_config.typ == "vmdb"
    end
  end

  DATA_DIR = Pathname.new(__dir__).join("data", File.basename(__FILE__, ".rb"))
  TEMPLATES = Dir.glob(DATA_DIR.join("*.tmpl.yml")).sort.each_with_object({}) do |f, h|
    h[File.basename(f, ".tmpl.yml")] = YAML.load_file(f).deep_symbolize_keys
  end
end
