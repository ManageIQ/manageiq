class BinaryBlobPart < ApplicationRecord
  validates :data, :presence => true

  def self.default_part_size
    @default_part_size ||= 1.megabyte
  end

  def inspect
    # Clean up inspect so that we don't flood script/console
    attrs = attribute_names.inject("{") do |s, n|
      s << "#{n.inspect}=>#{n == "data" ? "\"...\"" : read_attribute(n).inspect}, "
      s
    end
    attrs.chomp!(", ")
    attrs << "}"
    iv = instance_variables.inject(" ") do |s, v|
      s << "#{v}=#{v == "@attributes" ? attrs : instance_variable_get(v).inspect}, "
      s
    end
    iv.chomp!(", ")
    iv.rstrip!
    "#{to_s.chop}#{iv}>"
  end
end
