class RemoveDoubleSerializationInConfigurationSettingsColumn < ActiveRecord::Migration
  class Configuration < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    require 'yaml'
    say_with_time("Fixing double-serialized configurations") do
      Configuration.all.each do |c|
        value = YAML.load(c.settings)
        value = YAML.load(value) if value.kind_of?(String) && value.starts_with?("---")
        c.update_attribute(:settings, YAML.dump(value))
      end
    end
  end

  def down
    # Don't do anything.  Leave settings column serialized once.
  end
end
