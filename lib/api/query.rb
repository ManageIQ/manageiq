module Api
  module Query
    require 'graphql'

    def self.attribute_type(klass, attribute)
      attr = attribute.to_s
      return ::GraphQL::ID_TYPE if attr == "id"

      case klass.type_for_attribute(attr).type
      when :integer, :fixnum, :count
        ::GraphQL::INT_TYPE
      when :string
        ::GraphQL::STRING_TYPE
      when :float
        ::GraphQL::FLOAT_TYPE
      when :boolean
        ::GraphQL::BOOLEAN_TYPE
      else
        ::GraphQL::STRING_TYPE
      end
    end
  end
end
