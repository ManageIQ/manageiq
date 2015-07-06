class AddStartAddressToPartitions < ActiveRecord::Migration
  class Partition < ActiveRecord::Base
    serialize :reserved
  end

  def self.up
    add_column     :partitions,          :start_address,  :bigint

    say_with_time("Migrate data from reserved column") do
      Partition.where("reserved IS NOT NULL").each do |p|
        res = p.reserved
        p.start_address = res.delete(:start_address)
        p.reserved = res.empty? ? nil : res
        p.save
      end
    end
  end

  def self.down
    say_with_time("Migrate data to reserved column") do
      Partition.where("start_address IS NOT NULL").each do |p|
        p.reserved ||= {}
        p.reserved[:start_address] = p.start_address
        p.save
      end
    end

    remove_column  :partitions,          :start_address
  end
end
