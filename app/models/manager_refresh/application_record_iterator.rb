module ManagerRefresh
  class ApplicationRecordIterator
    attr_reader :inventory_collection, :manager_uuids_set, :iterator, :query

    # An iterator that can fetch batches of the AR objects based on a set of manager refs, or just mimics AR relation
    # when given an iterator. Or given query, acts as iterator by selecting batches.
    #
    # @param inventory_collection [ManagerRefresh::InventoryCollection] Inventory collection owning the iterator
    # @param manager_uuids_set [Array<ManagerRefresh::InventoryCollection::Reference>] Array of references we want to
    #        fetch from the DB
    # @param iterator [Proc] Block based iterator
    # @query query [ActiveRecord::Relation] Existing query we want to use for querying the db
    def initialize(inventory_collection: nil, manager_uuids_set: nil, iterator: nil, query: nil)
      @inventory_collection = inventory_collection
      @manager_uuids_set    = manager_uuids_set
      @iterator             = iterator
      @query                = query
    end

    # Iterator that mimics find_in_batches of ActiveRecord::Relation. This iterator serves for making more optimized query
    # since e.g. having 1500 ids if objects we want to return. Doing relation.where(:id => 1500ids).find_each would
    # always search for all 1500 ids, then return on limit 1000.
    #
    # With this iterator we build queries using only batch of ids, so find_each will cause relation.where(:id => 1000ids)
    # and relation.where(:id => 500ids)
    #
    # @param batch_size [Integer] A batch size we want to fetch from DB
    # @yield Code processing the batches
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

    # Iterator that mimics find_each of ActiveRecord::Relation using find_in_batches (see #find_in_batches)
    #
    # @yield Code processing the batches
    def find_each
      find_in_batches do |batch|
        batch.each do |item|
          yield(item)
        end
      end
    end
  end
end
