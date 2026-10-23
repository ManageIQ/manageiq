module TypeCastMixin
  extend ActiveSupport::Concern

  TYPE_MAP = {
    :boolean  => ActiveModel::Type::Boolean.new,
    :datetime => ActiveModel::Type::DateTime.new,
    :float    => ActiveModel::Type::Float.new,
    :integer  => ActiveModel::Type::Integer.new,
    :string   => ActiveModel::Type::String.new,
    :time     => ActiveModel::Type::Time.new
  }.freeze

  private

  def cast_to_type(type, value)
    return nil if value.nil?

    case type.to_s
    when "object", "array"
      JSON.parse(value)
    when "null"
      nil
    when *TYPE_MAP.keys.map(&:to_s)
      TYPE_MAP.fetch(type.to_sym).cast(value)
    else
      raise ArgumentError, "unknown type: [#{type}]"
    end
  end
end
