require 'recursive-open-struct'

describe ManageIQ::Providers::Elasticsearch::DatawarehouseManager::RefreshParser do
  let(:parser) { described_class.new }

  describe "get_elasticsearch_info_and_version" do
    let(:simple_info) do
      {
        "name"         => "name_of_node_with_master",
        "cluster_name" => "cluster_name",
        "cluster_uuid" => "cluster_uuid",
        "tagline"      => "search you know?",
        "version"      => {
          "number"          => "1.2.3",
          "build_hash"      => "build_hash",
          "build_timestamp" => "build_timestamp",
          "build_snapshot"  => "build_snapshot",
          "lucene_version"  => "lucene_version",
        }
      }
    end

    it "parses info and version correctly" do
      parser.send(:get_elasticsearch_info_and_version, simple_info)
      expect(parser.instance_variable_get('@data')[:cluster_attributes].pluck(:name, :value)).to eq(
        [
          ["version-name", "name_of_node_with_master"],
          ["version-cluster_name", "cluster_name"],
          ["version-cluster_uuid", "cluster_uuid"],
          ["version-tagline", "search you know?"],
          ["version-number", "1.2.3"],
          ["version-build_hash", "build_hash"],
          ["version-build_timestamp", "build_timestamp"],
          ["version-build_snapshot", "build_snapshot"],
          ["version-lucene_version", "lucene_version"]
        ]
      )
    end
  end

  describe "get_elasticsearch_cluster_health" do
    let(:simple_health) do
      {
        "cluster_name"          => "logging-es-ops",
        "status"                => "green",
        "timed_out"             => false,
        "number_of_nodes"       => 1,
        "number_of_data_nodes"  => 1,
        "active_primary_shards" => 20,
        "active_shards"         => 20,
      }
    end

    it "parses info and version correctly" do
      parser.send(:get_elasticsearch_cluster_health, simple_health)
      expect(parser.instance_variable_get('@data')[:cluster_attributes].pluck(:name, :value)).to eq(
        [
          ["health-cluster_name", "logging-es-ops"],
          ["health-status", "green"],
          ["health-timed_out", false],
          ["health-number_of_nodes", 1],
          ["health-number_of_data_nodes", 1],
          ["health-active_primary_shards", 20],
          ["health-active_shards", 20],
        ]
      )
    end
  end

  describe "get_datawarehouse_nodes" do
    let(:simple_nodes) do
      {
        "nodes" => {
          "SCARY_HASH" => {
            "name"       => "node_name",
            "host"       => "hostname",
            "ip"         => ["IPADDR:PORT", "NONE"],
            "attributes" => { "master" => "true" },
            "os"         => {
              "load_average" => 0.62,
              "cpu_percent"  => 7,
              "mem"          => { "used_percent" => 45 }
            },
            "jvm"        => { "mem" => { "heap_used_percent" => 4 }},
            "fs"         => {
              "total" => {
                "total_in_bytes"     => 100,
                "available_in_bytes" => 30
              }
            }
          }
        }
      }
    end

    it "parses info and version correctly" do
      parser.send(:get_datawarehouse_nodes, simple_nodes)
      expect(parser.instance_variable_get('@data')[:datawarehouse_nodes]).to eq(
        [{:ems_ref => "SCARY_HASH",
          :name    => "node_name",
          :host    => "hostname",
          :ip      => "IPADDR",
          :port    => "PORT",

          :master  => true,
          :load    => 0.62,
          :mem     => 45,
          :heap    => 4,
          :disk    => 70.0,
          :cpu     => 7}]
      )
    end
  end
end
