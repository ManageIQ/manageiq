class ConvertConfigurationsToSettingsChanges < ActiveRecord::Migration
  class Configuration < ActiveRecord::Base
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
    config      = full_config.settings.deep_symbolize_keys
    config_type = full_config.typ

    adjust_config!(config_type, config)

    deltas = Vmdb::Settings::HashDiffer.changes(TEMPLATES[config_type], config)
    deltas.each do |d|
      d.merge!(
        :resource_type => "MiqServer",
        :resource_id   => full_config.miq_server_id,
        :created_at    => full_config.created_on,
        :updated_at    => full_config.updated_on,
      )
      d[:key] = "/#{config_type}#{d[:key]}" unless config_type == "vmdb"
    end
  end

  def adjust_config!(type, config)
    case type
    when "broker_notify_properties"
      # Convert the various exclude sections from a Hash like
      #   {:key1 => nil, :key2 => nil} to an Array like ["key1", "key2"]
      excludes = config[:exclude]
      excludes.keys.each { |k| excludes[k] = excludes[k].keys.collect(&:to_s) }
    end
  end

  DATA_DIR = Pathname.new(__dir__).join("data", File.basename(__FILE__, ".rb"))
  TEMPLATES = Dir.glob(DATA_DIR.join("*.tmpl.yml")).sort.each_with_object({}) do |f, h|
    h[File.basename(f, ".tmpl.yml")] = YAML.load_file(f).deep_symbolize_keys
  end
end
