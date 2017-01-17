module ManageIQ::Providers
  module Elasticsearch
    class DatawarehouseManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
      include ::EmsRefresh::Refreshers::EmsRefresherMixin

      PARSERS_VERSIONS = {
        '1.7.6' => DatawarehouseManager::Parser_1_7_6,
        '2.4.1' => DatawarehouseManager::Parser_2_4_1,
      }.freeze
      DEFAULT_VERSION = '2.4.1'.freeze
      DEFAULT_PARSER = PARSERS_VERSIONS[DEFAULT_VERSION].freeze

      def retrieve_inventory(client)
        {
          :info   => client.info,
          :health => client.cluster.health,
          :nodes  => client.nodes.stats,
        }
      end

      def parse_legacy_inventory(ems)
        inventory = ems.with_provider_connection do |c|
          retrieve_inventory(c)
        end
        EmsRefresh.log_inv_debug_trace(inventory, "inv_hash:")
        PARSERS_VERSIONS.fetch(inventory[:info]["version"]["number"], DEFAULT_PARSER).ems_inv_to_hashes(inventory)
      end
    end
  end
end
