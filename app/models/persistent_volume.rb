class PersistentVolume < ContainerVolume
  acts_as_miq_taggable
  include NewWithTypeStiMixin
  has_one :persistent_volume_claim, :dependent => :destroy
  serialize :capacity, Hash
  delegate :name, :to => :parent, :prefix => true

  IEC_SIZE_SUFFIXES = %w(Ki Mi Gi Ti).freeze
  def self.parse_iec_number(value)
    return nil if value.nil?
    exp_index = IEC_SIZE_SUFFIXES.index(value[-2..-1])
    if exp_index.nil? && is_number?(value)
      return Integer(value)
    elsif exp_index
      return Integer(value[0..-3]) * 1024**(exp_index + 1)
    else
      return value
    end
  end

  def self.is_number?(string)
    true if Float(string) rescue false
  end
end
