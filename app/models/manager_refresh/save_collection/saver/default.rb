module ManagerRefresh::SaveCollection
  module Saver
    class Default < ManagerRefresh::SaveCollection::Saver::Base
      private

      # Updates the passed record with hash data and stores primary key value into inventory_object.
      #
      # @param record [ApplicationRecord] record we want to update in DB
      # @param hash [Hash] data we want to update the record with
      # @param inventory_object [ManagerRefresh::InventoryObject] InventoryObject instance where we will store primary
      #        key value
      def update_record!(record, hash, inventory_object)
        record.assign_attributes(hash.except(:id))
        if !inventory_collection.check_changed? || record.changed?
          record.save
          inventory_collection.store_updated_records(record)
        end

        inventory_object.id = record.id
      end

      # Creates a new record in the DB using the passed hash data
      #
      # @param hash [Hash] hash with data we want to persist to DB
      # @param inventory_object [ManagerRefresh::InventoryObject] InventoryObject instance where we will store primary
      #        key value
      def create_record!(hash, inventory_object)
        record = inventory_collection.model_class.create!(hash.except(:id))
        inventory_collection.store_created_records(record)

        inventory_object.id = record.id
      end

      # Asserts we do not have duplicate records in the DB. If the record is duplicate we will destroy it.
      #
      # @param record [ApplicationRecord] record we want to update in DB
      # @param index [String] manager_uuid of the record
      # @return [Boolean] false if the record is duplicate
      def assert_unique_record(record, index)
        # TODO(lsmola) can go away once we indexed our DB with unique indexes
        if unique_db_indexes.include?(index) # Include on Set is O(1)
          # We have a duplicate in the DB, destroy it. A find_each method does automatically .order(:id => :asc)
          # so we always keep the oldest record in the case of duplicates.
          _log.warn("A duplicate record was detected and destroyed, inventory_collection: "\
                        "'#{inventory_collection}', record: '#{record}', duplicate_index: '#{index}'")
          record.destroy
          return false
        else
          unique_db_indexes << index
        end
        true
      end
    end
  end
end
