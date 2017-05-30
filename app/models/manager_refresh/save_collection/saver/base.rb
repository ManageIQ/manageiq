module ManagerRefresh::SaveCollection
  module Saver
    class Base
      include Vmdb::Logging
      include ManagerRefresh::SaveCollection::Saver::SqlHelper

      attr_reader :inventory_collection

      def initialize(inventory_collection)
        @inventory_collection = inventory_collection

        # Private attrs
        @unique_index_keys      = inventory_collection.manager_ref_to_cols
        @unique_db_primary_keys = Set.new
      end

      def save_inventory_collection!
        # If we have a targeted InventoryCollection that wouldn't do anything, quickly skip it
        return if inventory_collection.noop?
        # If we want to use delete_complement strategy using :all_manager_uuids attribute, we are skipping any other
        # job. We want to do 1 :delete_complement job at 1 time, to keep to memory down.
        return delete_complement(inventory_collection) if inventory_collection.all_manager_uuids.present?

        # TODO(lsmola) do I need to reload every time? Also it should be enough to clear the associations.
        inventory_collection.parent.reload if inventory_collection.parent
        association = inventory_collection.db_collection_for_comparison

        save!(inventory_collection, association)
      end

      private

      attr_reader :unique_index_keys, :unique_db_primary_keys

      def batch_size
        1000
      end

      def delete_complement(inventory_collection)
        return unless inventory_collection.delete_allowed?

        all_manager_uuids_size = inventory_collection.all_manager_uuids.size

        _log.info("*************** PROCESSING :delete_complement of #{inventory_collection} of size "\
                  "#{all_manager_uuids_size} *************")
        deleted_counter = 0

        inventory_collection.db_collection_for_comparison_for_complement_of(
          inventory_collection.all_manager_uuids
        ).find_in_batches do |batch|
          ActiveRecord::Base.transaction do
            batch.each do |record|
              record.public_send(inventory_collection.delete_method)
              deleted_counter += 1
            end
          end
        end

        _log.info("*************** PROCESSED :delete_complement of #{inventory_collection} of size "\
                  "#{all_manager_uuids_size}, deleted=#{deleted_counter} *************")
      end

      def assert_distinct_relation(record)
        if unique_db_primary_keys.include?(record.id) # Include on Set is O(1)
          # Change the InventoryCollection's :association or :arel parameter to return distinct results. The :through
          # relations can return the same record multiple times. We don't want to do SELECT DISTINCT by default, since
          # it can be very slow.
          if Rails.env.production?
            _log.warn("Please update :association or :arel for #{inventory_collection} to return a DISTINCT result. "\
                        " The duplicate value is being ignored.")
            return false
          else
            raise("Please update :association or :arel for #{inventory_collection} to return a DISTINCT result. ")
          end
        else
          unique_db_primary_keys << record.id
        end
        true
      end

      def assert_referential_integrity(hash, inventory_object)
        inventory_object.inventory_collection.fixed_foreign_keys.each do |x|
          next unless hash[x].blank?
          _log.info("Ignoring #{inventory_object} because of missing foreign key #{x} for "\
                    "#{inventory_object.inventory_collection.parent.class.name}:"\
                    "#{inventory_object.inventory_collection.parent.id}")
          return false
        end
        true
      end
    end
  end
end
