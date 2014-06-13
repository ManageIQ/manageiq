require "spec_helper"
require Rails.root.join("db/migrate/20130801152053_remove_double_serialization_in_configuration_settings_column.rb")

describe RemoveDoubleSerializationInConfigurationSettingsColumn do
  migration_context :up do
    let(:configuration_stub) { migration_stub(:Configuration) }

    it "serialize settings once" do
      expected = {:a => {:b => :c}}
      good_config = configuration_stub.create!(:settings => YAML.dump(expected))
      bad_config  = configuration_stub.create!(:settings => YAML.dump(YAML.dump(expected)))

      migrate

      YAML.load(good_config.reload.settings).should == expected
      YAML.load(bad_config.reload.settings).should  == expected
    end
  end

  migration_context :down do
    let(:configuration_stub) { migration_stub(:Configuration) }

    it "leaves settings serialized once" do
      expected = {:a => {:b => :c}}
      good_config = configuration_stub.create!(:settings => YAML.dump(expected))

      migrate

      YAML.load(good_config.reload.settings).should == expected
    end
  end
end
