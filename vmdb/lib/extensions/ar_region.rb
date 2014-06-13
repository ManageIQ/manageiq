module ArRegion
  extend ActiveSupport::Concern

  DEFAULT_RAILS_SEQUENCE_FACTOR = 1_000_000_000_000

  included do
    cache_with_timeout(:id_to_miq_region) { Hash.new }
  end

  module ClassMethods
    def inherited(other)
      other.class_eval do
        virtual_column :region_number,      :type => :integer
        virtual_column :region_description, :type => :string
      end
      super
    end

    def my_region_number(force_reload = false)
      self.clear_region_cache if force_reload
      @@my_region_number ||= File.read(File.join(Rails.root, "REGION")).to_i rescue 0
    end

    def rails_sequence_factor
      DEFAULT_RAILS_SEQUENCE_FACTOR
    end

    def rails_sequence_start
      @@rails_sequence_start ||= self.my_region_number * self.rails_sequence_factor
    end

    def rails_sequence_end
      @@rails_sequence_end ||= self.rails_sequence_start + self.rails_sequence_factor - 1
    end

    def clear_region_cache
      @@my_region_number = @@rails_sequence_start = @@rails_sequence_end = nil
    end

    def id_to_region(id)
      return id.to_i / self.rails_sequence_factor
    end

    def region_to_range(region_number)
      (region_number * self.rails_sequence_factor)..(region_number * self.rails_sequence_factor + self.rails_sequence_factor - 1)
    end

    def region_to_conditions(region_number, col="id")
      ["#{col} >= ? AND #{col} <= ?", *self.region_to_array(region_number)]
    end

    def region_to_array(region_number)
      range = self.region_to_range(region_number)
      [range.first, range.last]
    end

    def in_my_region
      in_region(my_region_number)
    end

    def in_region(region_number)
      region_number.nil? ? scoped : where(:id => self.region_to_range(region_number))
    end

    def with_region(region_number)
      self.with_scope(:find => where(:id => self.region_to_range(region_number))) { yield }
    end

    def without_scope(&blk)
      self.with_exclusive_scope(&blk)
    end

    def conditions_for_my_region_default_scope
      # NOTE: These conditions MUST NOT be specified in Hash format because they are used for defining default_scope in models
      #       and would be applied for the creation of objects in addition to finds. Since :id is used in the condition this
      #       would result in all instances getting the the same id .
      ["#{self.quoted_table_name}.id >= ? AND #{self.quoted_table_name}.id <= ?", self.rails_sequence_start, self.rails_sequence_end]
    end

    def id_in_current_region?(id)
      self.id_to_region(id) == self.my_region_number
    end

    def split_id(id)
      return [my_region_number, nil] if id.nil?
      id = uncompress_id(id) if compressed_id?(id)
      id = id.to_i

      region_number = id_to_region(id)
      short_id      = (region_number == 0) ? id : id % (region_number * rails_sequence_factor)

      return region_number, short_id
    end

    #
    # ID compression
    #

    COMPRESSED_ID_SEPARATOR = 'r'
    RE_COMPRESSED_ID = /^(\d+)#{COMPRESSED_ID_SEPARATOR}(\d+)$/
    def compressed_id?(id)
      id.to_s =~ RE_COMPRESSED_ID
    end

    def compress_id(id)
      return nil if id.nil?
      region_number, short_id = split_id(id)
      (region_number == 0) ? short_id.to_s : "#{region_number}#{COMPRESSED_ID_SEPARATOR}#{short_id}"
    end

    def uncompress_id(compressed_id)
      return nil if compressed_id.nil?
      compressed_id.to_s =~ RE_COMPRESSED_ID ? ($1.to_i * rails_sequence_factor + $2.to_i) : compressed_id.to_i
    end

    #
    # Helper methods
    #

    # Partition the passed AR objects into local and remote sets
    def partition_objs_by_remote_region(objs)
      objs.partition { |o| o.in_current_region? }
    end

    # Partition the passed ids into local and remote sets
    def partition_ids_by_remote_region(ids)
      ids.partition { |id| self.id_in_current_region?(id) }
    end
  end

  def my_region_number
    self.class.my_region_number
  end

  def in_current_region?
    self.region_number == self.my_region_number
  end

  def region_number
    return my_region_number if self.new_record?
    self.id ? (self.id / self.class.rails_sequence_factor) : nil
  end
  alias region_id region_number

  def region_description
    self.miq_region.description if self.miq_region
  end

  def miq_region
    self.class.id_to_miq_region[region_number] || (self.class.id_to_miq_region[region_number] = MiqRegion.find_by_region(region_number))
  end

  def compressed_id
    self.class.compress_id(id)
  end

  def split_id
    self.class.split_id(id)
  end
end

ActiveRecord::Base.send(:include, ArRegion)
