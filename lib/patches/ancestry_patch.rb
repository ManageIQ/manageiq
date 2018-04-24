module Ancestry
  module InstanceMethods
    def parse_ancestry_column obj
      obj.to_s.split('/').map! { |id| cast_primary_key(id) }
    end

    STRING_BASED_KEYS = %i[string uuid text].freeze
    def cast_primary_key(key)
      if STRING_BASED_KEYS.include?(primary_key_type)
        key
      else
        key.to_i
      end
    end
  end
end
