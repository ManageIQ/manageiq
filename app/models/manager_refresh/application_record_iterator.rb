module ManagerRefresh
  class ApplicationRecordIterator
    attr_reader :inventory_collection, :manager_uuids_set, :iterator, :query

    # An iterator that can fetch batches of the AR objects based on a set of manager refs, or just mimics AR relation
    # when given an iterator
    def initialize(inventory_collection: nil, manager_uuids_set: nil, iterator: nil, query: nil)
      @inventory_collection = inventory_collection
      @manager_uuids_set    = manager_uuids_set
      @iterator             = iterator
      @query                = query
    end

    def find_in_batches(batch_size: 1000)
      if iterator
        iterator.call do |batch|
          yield(batch)
        end
      elsif query
        manager_uuids_set.each_slice(batch_size) do |batch|
          yield(query.where(inventory_collection.targeted_selection_for(batch)))
        end
      else
        manager_uuids_set.each_slice(batch_size) do |batch|
          yield(inventory_collection.db_collection_for_comparison_for(batch))
        end
      end
    end

    def find_each
      find_in_batches do |batch|
        batch.each do |item|
          yield(item)
        end
      end
    end
  end
end
