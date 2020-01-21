class FirmwareTarget < ApplicationRecord
  has_many :firmware_binary_firmware_targets, :dependent => :destroy
  has_many :firmware_binaries, :through => :firmware_binary_firmware_targets

  before_create :normalize
  before_save   :normalize

  # Attributes that need to match for target physical server to be assumed compatible.
  MATCH_ATTRIBUTES = %i[manufacturer model].freeze

  def normalize
    manufacturer.downcase!
    model.downcase!
  end

  # Firmware targets are nameless, but we need to show something on the UI.
  def name
    _('Firmware Target')
  end

  def to_hash
    attributes.symbolize_keys.slice(*MATCH_ATTRIBUTES)
  end

  def self.find_compatible_with(attributes, create: false)
    relevant_attrs = attributes.tap do |attrs|
      attrs.symbolize_keys!
      attrs.slice!(*MATCH_ATTRIBUTES)
      attrs.transform_values!(&:downcase)
    end
    create ? find_or_create_by(relevant_attrs) : find_by(relevant_attrs)
  end
end
