module TypeCastMixin
  extend ActiveSupport::Concern

  TYPE_MAP = {
    "boolean"  => ActiveModel::Type::Boolean.new,
    "datetime" => ActiveModel::Type::DateTime.new,
    "float"    => ActiveModel::Type::Float.new,
    "integer"  => ActiveModel::Type::Integer.new,
    "string"   => ActiveModel::Type::String.new,
    "time"     => ActiveModel::Type::Time.new,
    "object"   => ActiveRecord::Type::Json.new,
    "hash"     => ActiveRecord::Type::Json.new,
    "array"    => ActiveRecord::Type::Json.new
  }.freeze

  TYPE_MAP_KEYS = TYPE_MAP.keys

  private

  def cast_to_type(type, value)
    return nil if value.nil?

    case type.to_s
    when "null"
      nil
    when *TYPE_MAP_KEYS
      deserialized_val = TYPE_MAP.fetch(type.to_s).deserialize(value)

      raise TypeError, _("unacceptable value for type: [%{type}]") % {:type => type} if deserialized_val.nil?

      deserialized_val
    else
      raise ArgumentError, _("unknown type: [%{type}]") % {:type => type}
    end
  end
end
