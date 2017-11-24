module ManagerRefresh
  class InventoryCollection
    module Index
      module Type
        class LocalDb < ManagerRefresh::InventoryCollection::Index::Type::Base
          def initialize(inventory_collection, attribute_names, data_index)
            super

            @index             = nil
            @loaded_references = Set.new
            @data_index        = data_index
          end

          # Finds index_value in the DB. Using a configured strategy we cache obtained data in the index, so the
          # same find will not hit database twice. Also if we use lazy_links and this is called when
          # data_collection_finalized?, we load all data from the DB, referenced by lazy_links, in one query.
          #
          # @param index_value [String] a index_value of the InventoryObject we search in the local DB
          def find(index_value)
            # Use the cached index only data_collection_finalized?, meaning no new reference can occur
            if data_collection_finalized? && index
              return index[index_value]
            else
              return index[index_value] if index && index[index_value]
              # We haven't found the reference, lets add it to the list of references and load it
              references << index_value if index_value
            end

            # Put our existing data_index keys into loaded references
            loaded_references.merge(data_index.keys)
            # Load the rest of the references from the DB
            populate_index!

            index[index_value]
          end

          private

          attr_reader :data_index, :loaded_references
          attr_writer :index

          delegate :arel,
                   :association,
                   :association_to_base_class_mapping,
                   :association_to_foreign_key_mapping,
                   :association_to_foreign_type_mapping,
                   :attribute_references,
                   :build_multi_selection_condition,
                   :custom_manager_uuid,
                   :custom_db_finder,
                   :data_collection_finalized?,
                   :db_relation,
                   :model_class,
                   :new_inventory_object,
                   :parent,
                   :references,
                   :strategy,
                   :stringify_joiner,
                   :stringify_reference,
                   :to => :inventory_collection

          # Fills index with InventoryObjects obtained from the DB
          def populate_index!
            # Load only new references from the DB
            new_references = references - loaded_references
            # And store which references we've already loaded
            loaded_references.merge(new_references)

            # Initialize index in nil
            self.index ||= {}

            return if new_references.blank? # Return if all references are already loaded

            # TODO(lsmola) selected need to contain also :keys used in other InventoryCollections pointing to this one, once
            # we get list of all keys for each InventoryCollection ,we can uncomnent
            # selected   = [:id] + attribute_names.map { |x| model_class.reflect_on_association(x).try(:foreign_key) || x }
            # selected << :type if model_class.new.respond_to? :type
            # load_from_db.select(selected).find_each do |record|

            # Return the the correct relation based on strategy and selection&projection
            case strategy
            when :local_db_cache_all
              selection  = nil
              projection = nil
            else
              selection  = extract_references(new_references)
              projection = nil
            end

            db_relation(selection, projection).find_each do |record|
              process_db_record!(record)
            end
          end

          # Return a Rails relation or array that will be used to obtain the records we need to load from the DB
          #
          # @param selection [Hash] A selection hash resulting in Select operation (in Relation algebra terms)
          # @param projection [Array] A projection array resulting in Project operation (in Relation algebra terms)
          def db_relation(selection = nil, projection = nil)
            relation = if !custom_db_finder.blank?
                         custom_db_finder.call(self, selection, projection)
                       else
                         rel = if !parent.nil? && !association.nil?
                                 parent.send(association)
                               elsif !arel.nil?
                                 arel
                               end
                         rel = rel.where(build_multi_selection_condition(selection)) if rel && selection
                         rel = rel.select(projection) if rel && projection
                         rel
                       end

            relation || model_class.none
          end

          # Extracting references to a relation friendly format, or a format processable by a custom_db_finder
          #
          # @param new_references [Array] array of index_values of the InventoryObjects
          def extract_references(new_references = [])
            hash_uuids_by_ref = []

            new_references.each do |index_value|
              next if index_value.nil?
              # TODO(lsmola) no need when hashes are the original hashes
              uuids = index_value.split(stringify_joiner)

              reference = {}
              attribute_names.each_with_index do |ref, index_value|
                reference[ref] = uuids[index_value]
              end
              hash_uuids_by_ref << reference
            end
            hash_uuids_by_ref
          end

          # Takes ApplicationRecord record, converts it to the InventoryObject and places it to index
          #
          # @param record [ApplicationRecord] ApplicationRecord record we want to place to the index
          def process_db_record!(record)
            # TODO(lsmola) rethink this. If references will be the full Hash references, we can construct this automatically
            index_value = if custom_manager_uuid.nil?
                            inventory_collection.object_index_with_keys(attribute_names, record)
                          else
                            # TODO(lsmola) hm this will not really work for the secondary indexes anyway
                            stringify_reference(custom_manager_uuid.call(record))
                          end

            attributes = record.attributes.symbolize_keys
            attribute_references.each do |ref|
              # We need to fill all references that are relations, we will use a ManagerRefresh::ApplicationRecordReference which
              # can be used for filling a relation and we don't need to do any query here.
              # TODO(lsmola) maybe loading all, not just referenced here? Otherwise this will have issue for db_cache_all
              # and find used in parser
              # TODO(lsmola) the last usage of this should be lazy_find_by with :key specified, maybe we can get rid of this?
              next unless (foreign_key = association_to_foreign_key_mapping[ref])
              base_class_name = attributes[association_to_foreign_type_mapping[ref].try(:to_sym)] || association_to_base_class_mapping[ref]
              id              = attributes[foreign_key.to_sym]
              attributes[ref] = ManagerRefresh::ApplicationRecordReference.new(base_class_name, id)
            end

            index[index_value]    = new_inventory_object(attributes)
            index[index_value].id = record.id
          end
        end
      end
    end
  end
end
