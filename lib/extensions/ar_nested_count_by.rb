module ArNestedCountBy
  extend ActiveSupport::Concern

  module ClassMethods
    # This is like count by, but it produces a nested hash.
    #
    # @param fields fields to group by. e.g.: ["role", "state"]
    # @return [Hash<String,Hash<String,FixedNum>>] counts nested by each field
    #
    # example:
    #   nested_count_by("role", "state")
    #   => {'role1' => { 'error' => 5, 'ready' => 2}}

    def nested_count_by(*fields)
      group(fields.flatten).count.each.with_object({}) { |v, h| h.store_path(*v.flatten) }
    end
  end
end
