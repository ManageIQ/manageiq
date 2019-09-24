class MiqProductFeature < ApplicationRecord
  module Seeding
    extend ActiveSupport::Concern

    RELATIVE_FIXTURE_PATH = "db/fixtures/miq_product_features".freeze
    FIXTURE_PATH = Rails.root.join(RELATIVE_FIXTURE_PATH).freeze

    module ClassMethods
      def seed_files
        return seed_root_filename, seed_core_files + seed_plugin_files
      end

      private

      def seed_root_filename
        "#{FIXTURE_PATH}.yml"
      end

      def seed_core_files
        Dir.glob("#{FIXTURE_PATH}/*.y{,a}ml").sort
      end

      def seed_plugin_files
        Vmdb::Plugins.flat_map do |plugin|
          Dir.glob("#{plugin.root.join(RELATIVE_FIXTURE_PATH)}{.yml,.yaml,/*.yml,/*.yaml}").sort
        end
      end
    end
  end
end
