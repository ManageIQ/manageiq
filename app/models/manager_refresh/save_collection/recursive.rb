module ManagerRefresh::SaveCollection
  class Recursive
    extend ManagerRefresh::SaveCollection::Helper

    class << self
      def save_collections(ems, dto_collections)
        graph = ManagerRefresh::DtoCollection::Graph.new(dto_collections.values)
        graph.build_directed_acyclic_graph!

        graph.nodes.each do |dto_collection|
          save_collection(ems, dto_collection, [])
        end
      end

      private

      def save_collection(ems, dto_collection, traversed_collections)
        unless dto_collection.kind_of? ::ManagerRefresh::DtoCollection
          raise "A ManagerRefresh::SaveInventory needs a DtoCollection object, it got: #{dto_collection.inspect}"
        end

        return if dto_collection.saved?

        traversed_collections << dto_collection

        unless dto_collection.saveable?
          dto_collection.dependencies.each do |dependency|
            if traversed_collections.include? dependency
              raise "Edge from #{dto_collection} to #{dependency} creates a cycle"
            end
            save_collection(ems, dependency, traversed_collections)
          end
        end

        _log.info("Saving #{dto_collection} of size #{dto_collection.size}")
        save_dto_inventory(ems, dto_collection)
      end
    end
  end
end
