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
        @unique_db_indexes      = Set.new
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

      attr_reader :unique_index_keys, :unique_db_primary_keys, :unique_db_indexes

      def save!(inventory_collection, association)
        attributes_index        = {}
        inventory_objects_index = {}
        inventory_collection.each do |inventory_object|
          attributes = inventory_object.attributes(inventory_collection)
          index      = inventory_object.manager_uuid

          attributes_index[index]        = attributes
          inventory_objects_index[index] = inventory_object
        end

        _log.info("*************** PROCESSING #{inventory_collection} of size #{inventory_collection.size} *************")
        # Records that are in the DB, we will be updating or deleting them.
        ActiveRecord::Base.transaction do
          association.find_each do |record|
            index = inventory_collection.object_index_with_keys(unique_index_keys, record)

            next unless assert_distinct_relation(record)
            next unless assert_unique_record(record, index)

            inventory_object = inventory_objects_index.delete(index)
            hash             = attributes_index.delete(index)

            if inventory_object.nil?
              # Record was found in the DB but not sent for saving, that means it doesn't exist anymore and we should
              # delete it from the DB.
              delete_record!(inventory_collection, record) if inventory_collection.delete_allowed?
            else
              # Record was found in the DB and sent for saving, we will be updating the DB.
              update_record!(inventory_collection, record, hash, inventory_object) if assert_referential_integrity(hash, inventory_object)
            end
          end
        end

        unless inventory_collection.custom_reconnect_block.nil?
          inventory_collection.custom_reconnect_block.call(inventory_collection, inventory_objects_index, attributes_index)
        end

        # Records that were not found in the DB but sent for saving, we will be creating these in the DB.
        if inventory_collection.create_allowed?
          ActiveRecord::Base.transaction do
            inventory_objects_index.each do |index, inventory_object|
              hash = attributes_index.delete(index)

              create_record!(inventory_collection, hash, inventory_object) if assert_referential_integrity(hash, inventory_object)
            end
          end
        end
        _log.info("*************** PROCESSED #{inventory_collection}, "\
                  "created=#{inventory_collection.created_records.count}, "\
                  "updated=#{inventory_collection.updated_records.count}, "\
                  "deleted=#{inventory_collection.deleted_records.count} *************")
      end

      def batch_size
        inventory_collection.batch_size
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

      def delete_record!(inventory_collection, record)
        record.public_send(inventory_collection.delete_method)
        inventory_collection.store_deleted_records(record)
      end

      def assert_unique_record(_record, _index)
        # TODO(lsmola) can go away once we indexed our DB with unique indexes
        true
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
          _log.info("Ignoring #{inventory_object} of #{inventory_object.inventory_collection} because of missing foreign key #{x} for "\
                    "#{inventory_object.inventory_collection.parent.class.name}:"\
                    "#{inventory_object.inventory_collection.parent.try(:id)}")
          return false
        end
        true
      end

      def time_now
        # A rails friendly time getting config from ActiveRecord::Base.default_timezone (can be :local or :utc)
        if ActiveRecord::Base.default_timezone == :utc
          Time.now.utc
        else
          Time.zone.now
        end
      end

      def supports_remote_data_timestamp?(all_attribute_keys)
        all_attribute_keys.include?(:remote_data_timestamp) # include? on Set is O(1)
      end

      def assign_attributes_for_update!(hash, inventory_collection, update_time)
        hash[:last_sync_on] = update_time if inventory_collection.supports_last_sync_on?
        hash[:updated_on]   = update_time if inventory_collection.supports_timestamps_on_variant?
        hash[:updated_at]   = update_time if inventory_collection.supports_timestamps_at_variant?
      end

      def assign_attributes_for_create!(hash, inventory_collection, create_time)
        hash[:type]         = inventory_collection.model_class.name if inventory_collection.supports_sti? && hash[:type].blank?
        hash[:created_on]   = create_time if inventory_collection.supports_timestamps_on_variant?
        hash[:created_at]   = create_time if inventory_collection.supports_timestamps_at_variant?
        assign_attributes_for_update!(hash, inventory_collection, create_time)
      end
    end
  end
end
