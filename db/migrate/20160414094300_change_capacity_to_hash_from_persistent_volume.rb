class ChangeCapacityToHashFromPersistentVolume < ActiveRecord::Migration[5.0]
  class ContainerVolume < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  class PersistentVolume < ContainerVolume
    self.inheritance_column = :_type_disabled # disable STI
    serialize :capacity
  end

  def up
    change_column :container_volumes, :capacity, :text
    say_with_time("Changing string to hash") do
      PersistentVolume.find_each do |vol|
        result_hash = {}
        unless vol.capacity.nil?
          vol.capacity.split(',').each do |hash|
            key, val = hash.split('=')
            next if val.nil?
            begin
              result_hash[key.to_sym] = val.to_iec_integer
            rescue ArgumentError
              _log.warn("Capacity attribute was in bad format - #{val}")
            end
          end
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
