module ManagerRefresh
  class InventoryCollection
    module Index
      module Type
        class LocalDb < ManagerRefresh::InventoryCollection::Index::Type::Base
          def initialize(inventory_collection, index_name, attribute_names, data_index)
            super

            @index                 = nil
            @loaded_references     = Set.new
            @data_index            = data_index
            @all_references_loaded = false
          end

          # Finds reference in the DB. Using a configured strategy we cache obtained data in the index, so the
          # same find will not hit database twice. Also if we use lazy_links and this is called when
          # data_collection_finalized?, we load all data from the DB, referenced by lazy_links, in one query.
          #
          # @param reference [String] a ManagerRefresh::InventoryCollection::Reference object
          def find(reference)
            # Use the cached index only data_collection_finalized?, meaning no new reference can occur
            if data_collection_finalized? && all_references_loaded? && index
              return index[reference.stringified_reference]
            else
              return index[reference.stringified_reference] if index && index[reference.stringified_reference]
              # We haven't found the reference, lets add it to the list of references and load it
              add_reference(reference)
            end

            # Put our existing data_index keys into loaded references
            loaded_references.merge(data_index.keys)
            # Load the rest of the references from the DB
            populate_index!

            self.all_references_loaded = true if data_collection_finalized?

            index[reference.stringified_reference]
          end

          private

          attr_accessor :all_references_loaded, :schema
          attr_reader :data_index, :loaded_references
          attr_writer :index

          delegate :add_reference,
                   :arel,
                   :association,
                   :association_to_base_class_mapping,
                   :association_to_foreign_key_mapping,
                   :association_to_foreign_type_mapping,
                   :attribute_references,
                   :data_collection_finalized?,
                   :db_relation,
                   :inventory_object?,
                   :inventory_object_lazy?,
                   :model_class,
                   :new_inventory_object,
                   :parent,
                   :references,
                   :strategy,
                   :stringify_joiner,
                   :table_name,
                   :to => :inventory_collection

          alias all_references_loaded? all_references_loaded

          # Fills index with InventoryObjects obtained from the DB
          def populate_index!
            # Load only new references from the DB
            new_references = index_references - loaded_references
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

            full_references = references[index_name].select { |key, _value| new_references.include?(key) } # O(1) include on Set
            full_references = full_references.values.map(&:full_reference)

            schema                         = get_schema(full_references)
            paths                          = schema.keys
            rails_friendly_includes_schema = get_rails_friendly_includes_schema(paths)

            all_values = []
            full_references.each do |ref|
              value = []
              schema.each_key do |schema_item_path|
                value << fetch_hash_path(schema_item_path, ref)
              end
              all_values << value
            end

            # Return the the correct relation based on strategy and selection&projection
            projection = nil

            db_relation(rails_friendly_includes_schema, schema.values, all_values, projection).find_each do |record|
              process_db_record!(record, paths)
            end
          end

          # Builds a multiselection conditions like (table1.a, table2.b) IN ((a1, b1), (a2, b2))
          # @param column_names [Array] Array of column names in format "<table_name>.<column_name>"
          # @param all_values [Array<Array>] nested array of values in format [[a1, b1], [a2, b2]] the nested array
          #        values must have the order of column_names
          # @return [String] A condition e.g. (table1.a, table2.b) IN ((a1, b1), (a2, b2)), usable in .where of an
          #         ActiveRecord relation
          def build_multi_selection_condition(column_names, all_values)
            cond_data = all_values.map do |values|
              "(#{values.map { |x| ActiveRecord::Base.connection.quote(x) }.join(",")})"
            end.join(",")
            column_names = column_names.join(",")

            "(#{column_names}) IN (#{cond_data})"
          end

          # Traverses the schema_item_path e.g. [:hardware, :vm_or_template, :ems_ref] and gets the value on the path
          # in hash.
          # @param path [Array] path for traversing hash e.g. [:hardware, :vm_or_template, :ems_ref]
          # @param hash [Hash] nested hash with data e.g. {:hardware => {:vm_or_template => {:ems_ref => "value"}}}
          # @return [Object] value in the Hash on the path, in the example that would be "value"
          def fetch_hash_path(path, hash)
            path.inject(hash) { |x, r| x.try(:[], r) }
          end

          # Traverses the schema_item_path e.g. [:hardware, :vm_or_template, :ems_ref] and gets the value on the path
          # in object.
          # @param path [Array] path for traversing hash e.g. [:hardware, :vm_or_template, :ems_ref]
          # @param object [ApplicationRecord] an ApplicationRecord fetched from the DB
          # @return [Object] value in the Hash on the path, in the example that would be "value"
          def fetch_object_path(path, object)
            path.inject(object) { |x, r| x.public_send(r) }
          end

          def get_schema(full_references)
            @schema ||= get_schema_recursive(attribute_names, table_name, full_references.first, {}, [], 0)
          end

          # Converts an array of paths to attributes in different DB tables into rails friendly format, that can be used
          # for correct DB JOIN of those tables (references&includes methods)
          # @param [Array[Array]] Nested array with paths e.g. [[:hardware, :vm_or_template, :ems_ref], [:description]
          # @return [Array] A rails friendly format for ActiveRecord relation .includes and .references
          def get_rails_friendly_includes_schema(paths)
            return @rails_friendly_includes_schema if @rails_friendly_includes_schema

            nested_hashes_schema = {}
            # Ignore last value in path and build nested hash from paths, e.g. paths
            # [[:hardware, :vm_or_template, :ems_ref], [:description] will be transformed to
            # [[:hardware, :vm_or_template]], so only relations we need for DB join and then to nested hash
            # {:hardware => {:vm_or_template => {}}}
            paths.map { |x| x[0..-2] }.select(&:present?).each { |x| nested_hashes_schema.store_path(x, {}) }
            # Convert nested Hash to Rails friendly format, e.g. {:hardware => {:vm_or_template => {}}} will be
            # transformed to [:hardware => :vm_or_template]
            @rails_friendly_includes_schema = transform_hash_to_rails_friendly_array_recursive(nested_hashes_schema, [])
          end

          def transform_hash_to_rails_friendly_array_recursive(hash, current_layer)
            array_attributes, hash_attributes = hash.partition { |_key, value| value.blank? }

            array_attributes = array_attributes.map(&:first)
            current_layer.concat(array_attributes)
            # current_array.concat(array_attributes)
            if hash_attributes.present?
              last_hash_attr = hash_attributes.each_with_object({}) do |(key, value), obj|
                obj[key] = transform_hash_to_rails_friendly_array_recursive(value, [])
              end
              current_layer << last_hash_attr
            end

            current_layer
          end

          def get_schema_recursive(attribute_names, table_name, data, schema, path, total_level)
            raise "Nested too deep" if total_level > 100

            attribute_names.each do |key|
              new_path = path + [key]

              value = data[key]

              if inventory_object?(value)
                get_schema_recursive(value.inventory_collection.manager_ref,
                                     value.inventory_collection.table_name,
                                     value,
                                     schema,
                                     new_path,
                                     total_level + 1)
              elsif inventory_object_lazy?(value)
                get_schema_recursive(value.inventory_collection.index_proxy.named_ref(value.ref),
                                     value.inventory_collection.table_name,
                                     value.reference.full_reference,
                                     schema,
                                     new_path,
                                     total_level + 1)
              else
                schema[new_path] = "#{table_name}.#{ActiveRecord::Base.connection.quote_column_name(key)}"
              end
            end

            schema
          end

          def index_references
            Set.new(references[index_name].try(:keys) || [])
          end

          # Return a Rails relation that will be used to obtain the records we need to load from the DB
          #
          # @param rails_friendly_includes_schema [Array] Schema usable in .includes and .references methods of
          #        ActiveRecord relation object
          # @param column_names [Array] Array of column names in format "<table_name>.<column_name>"
          # @param all_values [Array<Array>] nested array of values in format [[a1, b1], [a2, b2]] the nested array
          #        values must have the order of column_names
          # @param projection [Array] A projection array resulting in Project operation (in Relation algebra terms)
          # @return [ActiveRecord::AssociationRelation] relation object having filtered data
          def db_relation(rails_friendly_includes_schema, column_names, all_values = nil, projection = nil)
            relation = if !parent.nil? && !association.nil?
                         parent.send(association)
                       elsif !arel.nil?
                         arel
                       end
            relation = relation.where(build_multi_selection_condition(column_names, all_values)) if relation && all_values
            relation = relation.select(projection) if relation && projection
            relation = relation.includes(rails_friendly_includes_schema).references(rails_friendly_includes_schema) if rails_friendly_includes_schema.present?
            relation || model_class.none
          end

          # Takes ApplicationRecord record, converts it to the InventoryObject and places it to index
          #
          # @param record [ApplicationRecord] ApplicationRecord record we want to place to the index
          def process_db_record!(record, paths)
            # Important fact is that the path was added as .includes in the query, so this doesn't generate n+1 queries
            index_value = ManagerRefresh::InventoryCollection::Reference.stringify_reference(
              paths.map { |path| fetch_object_path(path, record) }
            )

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
