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
    diff = diff_hashes(TEMPLATES[full_config.typ], full_config.settings)
    deltas = diff_to_deltas(diff)
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

  # Inspired by http://stackoverflow.com/questions/1766741/comparing-ruby-hashes
  MISSING_KEY = "*****MISSING*****"
  def diff_hashes(before, after)
    (before.keys + after.keys).uniq.inject({}) do |memo, key|
      unless (before.key?(key) && after.key?(key) && before[key] == after[key])
        if before[key].kind_of?(Hash) && after[key].kind_of?(Hash)
          memo[key] = diff_hashes(before[key], after[key])
        else
          value_before = before.key?(key) ? before[key] : MISSING_KEY
          value_after  = after.key?(key)  ? after[key]  : MISSING_KEY
          memo[key] = [value_before, value_after]
        end
      end
      memo
    end
  end

  def diff_to_deltas(changes, parent_key = "")
    changes.flat_map do |key, values|
      key = File.join(parent_key, key)
      case values
      when Hash
        diff_to_deltas(values, key)
      else
        value = values.last
        {:key => key, :value => value} unless value == MISSING_KEY
      end
    end.compact
  end

  # TODO: Replace the vmdb key with a hardcoded Hash
  # TODO: Add the rest of the convertable config types
  TEMPLATES = {
    "vmdb" => YAML.load_file(Rails.root.join("config/vmdb.tmpl.yml"))
  }
end
