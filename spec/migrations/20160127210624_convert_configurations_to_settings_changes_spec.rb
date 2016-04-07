require "spec_helper"
require_migration

describe ConvertConfigurationsToSettingsChanges do
  let(:data_dir) { Pathname.new(__dir__).join("data", File.basename(__FILE__, ".rb")) }
  let(:config_stub) { migration_stub(:Configuration) }
  let(:settings_change_stub) { migration_stub(:SettingsChange) }

  migration_context :up do
    it 'converts migration data with fake templates' do
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
        :typ           => "vmdb",
        :miq_server_id => 2,
        :settings      => {
          "values" => {
            "string" => "vmdb value",
          },
        }
      )

      _non_existing_tmpl_file = config_stub.create!(
        :typ           => "hostdefaults",
        :miq_server_id => 2,
        :settings      => {
          "values" => {
            "string" => "hostdefaults value",
          },
        }
      )

      test_templates = {
        "simple" => YAML.load_file(data_dir.join("simple.tmpl.yml")).deep_symbolize_keys,
        "vmdb"   => YAML.load_file(data_dir.join("simple.tmpl.yml")).deep_symbolize_keys
      }
      described_class.with_constants(:TEMPLATES => test_templates) do
        migrate
      end

      expect(settings_change_stub.count).to eq(12)

      deltas = settings_change_stub.where("key LIKE '/simple/%'").order(:id)
      expect(deltas.size).to eq(11)
      expect(deltas.collect(&:resource_type).uniq).to eq ["MiqServer"]
      expect(deltas.collect(&:resource_id).uniq).to eq [1]

      expect(deltas[0]).to have_attributes(
        :key   => "/simple/values/array",
        :value => ["new val1", "new val2"]
      )
      expect(deltas[1]).to have_attributes(
        :key   => "/simple/values/boolean",
        :value => false
      )
      expect(deltas[2]).to have_attributes(
        :key   => "/simple/values/empty_hash/key1",
        :value => "x"
      )
      expect(deltas[3]).to have_attributes(
        :key   => "/simple/values/empty_hash/key2",
        :value => "y"
      )
      expect(deltas[4]).to have_attributes(
        :key   => "/simple/values/int_with_method",
        :value => "20.minutes"
      )
      expect(deltas[5]).to have_attributes(
        :key   => "/simple/values/integer",
        :value => 99
      )
      expect(deltas[6]).to have_attributes(
        :key   => "/simple/values/nil",
        :value => "not nil"
      )
      expect(deltas[7]).to have_attributes(
        :key   => "/simple/values/non_nil",
        :value => "not nil"
      )
      expect(deltas[8]).to have_attributes(
        :key   => "/simple/values/string",
        :value => "new value"
      )
      expect(deltas[9]).to have_attributes(
        :key   => "/simple/values/non_existant",
        :value => "exists"
      )
      expect(deltas[10]).to have_attributes(
        :key   => "/simple/very/deeply/nested/string",
        :value => "new value"
      )

      deltas = settings_change_stub.where.not("key LIKE '/simple/%'").order(:key)
      expect(deltas.size).to eq(1)

      expect(deltas.first).to have_attributes(
        :resource_type => "MiqServer",
        :resource_id   => 2,
        :key           => "/values/string",
        :value         => "vmdb value",
      )
    end

    it 'converts migration data with real templates' do
      vmdb_data = stringify_first_two_levels(described_class::TEMPLATES["vmdb"])
      vmdb_data.store_path("api", "token_ttl", "1.second")
      config_stub.create!(
        :typ           => "vmdb",
        :miq_server_id => 1,
        :settings      => vmdb_data
      )

      storage_data = stringify_first_two_levels(described_class::TEMPLATES["storage"])
      storage_data.store_path("alignment", "boundary", "1.byte")
      config_stub.create!(
        :typ           => "storage",
        :miq_server_id => 2,
        :settings      => storage_data
      )

      broker_notify_data = {
        "exclude" => {
          "HostSystem" => {
            "config.property1" => nil,
            "config.property2" => nil
          },
          "VirtualMachine" => {
            "config.property3" => nil,
            "config.property4" => nil
          }
        },
      }
      config_stub.create!(
        :typ           => "broker_notify_properties",
        :miq_server_id => 3,
        :settings      => broker_notify_data
      )

      migrate

      deltas = settings_change_stub.where(:resource_id => 1)
      expect(deltas.size).to eq(1)

      expect(deltas.first).to have_attributes(
        :resource_type => "MiqServer",
        :resource_id   => 1,
        :key           => "/api/token_ttl",
        :value         => "1.second",
      )

      deltas = settings_change_stub.where(:resource_id => 2)
      expect(deltas.size).to eq(1)

      expect(deltas.first).to have_attributes(
        :resource_type => "MiqServer",
        :resource_id   => 2,
        :key           => "/storage/alignment/boundary",
        :value         => "1.byte",
      )

      deltas = settings_change_stub.where(:resource_id => 3).order(:key)
      expect(deltas.size).to eq(2)

      expect(deltas[0]).to have_attributes(
        :resource_type => "MiqServer",
        :resource_id   => 3,
        :key           => "/broker_notify_properties/exclude/HostSystem",
        :value         => %w(config.property1 config.property2),
      )
      expect(deltas[1]).to have_attributes(
        :resource_type => "MiqServer",
        :resource_id   => 3,
        :key           => "/broker_notify_properties/exclude/VirtualMachine",
        :value         => %w(config.property3 config.property4),
      )
    end
  end

  private

  def stringify_first_two_levels(hash)
    hash = hash.stringify_keys
    hash.keys.each { |k| hash[k] = hash[k].stringify_keys }
    hash
  end
end
