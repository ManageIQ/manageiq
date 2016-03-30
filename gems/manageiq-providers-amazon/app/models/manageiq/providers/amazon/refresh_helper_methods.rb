module ManageIQ::Providers::Amazon::RefreshHelperMethods
  extend ActiveSupport::Concern

  def process_collection(collection, key)
    @data[key] ||= []

    collection.each do |item|
      uid, new_result = yield(item)
      next if uid.nil?

      @data[key] << new_result
      @data_index.store_path(key, uid, new_result)
    end
  end

  ARCHITECTURE_TO_BITNESS = {
    :i386   => 32,
    :x86_64 => 64,
  }.freeze

  def architecture_to_bitness(arch)
    ARCHITECTURE_TO_BITNESS[arch.to_sym]
  end

  # Remap from children to parent
  def update_nested_stack_relations
    @data[:orchestration_stacks].each do |stack|
      stack[:children].each do |child_stack_id|
        child_stack = @data_index.fetch_path(:orchestration_stacks, child_stack_id)
        child_stack[:parent] = stack if child_stack
      end
      stack.delete(:children)
    end
  end

  def get_from_tags(resource, item)
    resource.tags.detect { |tag, _| tag.key.downcase == item.to_s.downcase }.try(:value)
  end

  def add_instance_disk(disks, size, name, location)
    super(disks, size, name, location, "amazon")
  end

  # Compose an ems_ref combining some existing keys
  def compose_ems_ref(*keys)
    keys.join('_')
  end

  module ClassMethods
    def ems_inv_to_hashes(ems, options = nil)
      new(ems, options).ems_inv_to_hashes
    end
  end
end
