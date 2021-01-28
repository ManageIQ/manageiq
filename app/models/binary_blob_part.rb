class BinaryBlobPart < ApplicationRecord
  validates :data, :presence => true

  def self.default_part_size
    @default_part_size ||= 1.megabyte
  end

  # Clean up inspect so that we don't flood rails console
  def self.filter_attributes
    super + [:data]
  end
end
