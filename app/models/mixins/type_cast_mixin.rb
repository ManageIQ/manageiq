module TypeCastMixin
  extend ActiveSupport::Concern

  TYPE_MAP = {
    :boolean  => ActiveModel::Type::Boolean.new,
    :datetime => ActiveModel::Type::DateTime.new,
    :float    => ActiveModel::Type::Float.new,
    :integer  => ActiveModel::Type::Integer.new,
    :string   => ActiveModel::Type::String.new,
    :time     => ActiveModel::Type::Time.new,
    :object   => ActiveRecord::Type::Json.new,
    :array    => ActiveRecord::Type::Json.new
  }.freeze

  TYPE_MAP_KEYS = TYPE_MAP.keys

  private

  def cast_to_type(type, value)
    return nil if value.nil?

    case type.to_sym
    when :null
      nil
    when *TYPE_MAP_KEYS
      TYPE_MAP.fetch(type.to_sym).deserialize(value)
    else
      raise ArgumentError, "unknown type: [#{type}]"
    end
  end
end
