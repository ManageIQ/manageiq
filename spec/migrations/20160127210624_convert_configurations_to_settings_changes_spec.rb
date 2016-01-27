require "spec_helper"
require_migration

describe ConvertConfigurationsToSettingsChanges do
  let(:data_dir) { Pathname.new(__dir__).join("data", File.basename(__FILE__, ".rb")) }
  let(:config_stub) { migration_stub(:Configuration) }
  let(:settings_change_stub) { migration_stub(:SettingsChange) }

  migration_context :up do
    it 'converts migration data' do
      config_stub.create!(
        :typ           => "simple",
        :miq_server_id => 1,
        :settings      => {
          "values" => {
            "array"           => ["new val1", "new val2"],
            "boolean"         => false,
            "empty_hash"      => {"key1" => "x", "key2" => "y"},
            "int_with_method" => "20.minutes",
            "integer"         => 99,
            "nil"             => "not nil",
            "non_existant"    => "exists",
            "non_nil"         => "not nil",
            "string"          => "new value",
          },
          "very"   => {
            "deeply" => {
              "nested" => {
                "string" => "new value"
              }
            }
          }
        }
      )

      config_stub.create!(
        :typ           => "other",
        :miq_server_id => 2,
        :settings      => {
          "values" => {
            "string" => "other value",
          },
        }
      )

      test_templates = {
        "simple" => YAML.load_file(data_dir.join("simple.tmpl.yml")),
        "other"  => YAML.load_file(data_dir.join("simple.tmpl.yml"))
      }
      described_class.with_constants(:TEMPLATES => test_templates) do
        migrate
      end

      expect(settings_change_stub.count).to eq(12)

      deltas = settings_change_stub.where(:name => "simple").order(:id)
      expect(deltas.size).to eq(11)

      deltas.each do |d|
        expect(d).to have_attributes(
          :name          => "simple",
          :resource_type => "MiqServer",
          :resource_id   => 1,
        )
      end

      expect(deltas[0]).to have_attributes(
        :key   => "/values/array",
        :value => ["new val1", "new val2"]
      )
      expect(deltas[1]).to have_attributes(
        :key   => "/values/boolean",
        :value => false
      )
      expect(deltas[2]).to have_attributes(
        :key   => "/values/empty_hash/key1",
        :value => "x"
      )
      expect(deltas[3]).to have_attributes(
        :key   => "/values/empty_hash/key2",
        :value => "y"
      )
      expect(deltas[4]).to have_attributes(
        :key   => "/values/int_with_method",
        :value => "20.minutes"
      )
      expect(deltas[5]).to have_attributes(
        :key   => "/values/integer",
        :value => 99
      )
      expect(deltas[6]).to have_attributes(
        :key   => "/values/nil",
        :value => "not nil"
      )
      expect(deltas[7]).to have_attributes(
        :key   => "/values/non_existant",
        :value => "exists"
      )
      expect(deltas[8]).to have_attributes(
        :key   => "/values/non_nil",
        :value => "not nil"
      )
      expect(deltas[9]).to have_attributes(
        :key   => "/values/string",
        :value => "new value"
      )
      expect(deltas[10]).to have_attributes(
        :key   => "/very/deeply/nested/string",
        :value => "new value"
      )

      deltas = settings_change_stub.where(:name => "other").order(:key)
      expect(deltas.size).to eq(1)

      expect(deltas.first).to have_attributes(
        :name          => "other",
        :resource_type => "MiqServer",
        :resource_id   => 2,
        :key           => "/values/string",
        :value         => "other value",
      )
    end
  end
end
