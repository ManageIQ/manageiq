module Api
  class QueryController < BaseController
    require 'graphql'

    ApiCollectionConfig = Api::CollectionConfig.new

    query_types = []

    ApiCollectionConfig.collections_with_description.each do |collection, desc|
      klass = ApiCollectionConfig.klass(collection)
      next if klass.nil?

      query_type = GraphQL::ObjectType.define do
        name collection.to_s
        description desc

        attributes = klass.attribute_names - klass.virtual_attribute_names
        attributes.each do |attr|
          field attr.to_sym, ::Api::Query.attribute_type(klass, attr)
        end

        virtual_attributes = klass.virtual_attribute_names
        virtual_attributes.each do |attr|
          field attr.to_sym, ::Api::Query.attribute_type(klass, attr)
        end

        reflections = klass.reflections.merge(klass.virtual_reflections)
        reflections.each do |name, _association|
          field name.to_sym, ::Api::Query.attribute_type(klass, name)
        end
      end

      query_types << [collection, desc, query_type, klass]
    end

    QueryType = GraphQL::ObjectType.define do
      name "Query"
      description "The query root of this schema"

      query_types.each do |collection, desc, query_type, klass|
        field collection do
          type query_type
          argument :id, !types.ID
          description "Find #{desc} by id"
          resolve ->(_obj, args, _ctx) { klass.find(args["id"]) }
        end
      end
    end

    Schema = GraphQL::Schema.define do
      query QueryType
    end

    def update
      run_query(json_body_resource)
    end

    def options
      render_options(:query, :schema => GraphQL::Introspection::INTROSPECTION_QUERY)
    end

    private

    def validate_query_data(data)
      query = data["query"]
      raise BadRequestError, "Missing query" if query.blank?
      query
    end

    def validate_query_type(query_type)
      raise BadRequestError, "Unsupported query type #{query_type}" if query_type != "graphql"
    end

    def run_query(data)
      query_type = data["query_type"] || "graphql"
      validate_query_type(query_type)

      variables = data["variables"] || {}

      query = validate_query_data(data)
      render_normal_update :query, Schema.execute(query, :variables => variables)
    end
  end
end
