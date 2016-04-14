class ChangeCapacityToHashFromPersistentVolume < ActiveRecord::Migration[5.0]
  class ContainerVolume < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  class PersistentVolume < ContainerVolume
    self.inheritance_column = :_type_disabled # disable STI
    serialize :capacity

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

  def up
    change_column :container_volumes, :capacity, :text
    say_with_time("Changing string to hash") do
      PersistentVolume.find_each do |vol|
        next if vol.capacity.nil?
        result_hash = {}
        vol.capacity.split(',').each do |hash|
          key, val = hash.split('=')
          next if val.nil?
          result_hash[key.to_sym] =  PersistentVolume.parse_iec_number val
        end
        vol.update_attributes!(:capacity => result_hash)
      end
    end
  end

  def down
    say_with_time("Changing hash to string") do
      PersistentVolume.find_each do |vol|
        next if vol.capacity.nil?
        capacity = vol.capacity.collect { |key, val| "#{key}=#{val}" }.join(",")
        capacity = nil if capacity.blank?
        vol.update_attributes!(:capacity => capacity)
      end
    end
    change_column :container_volumes, :capacity, :string
  end
end
