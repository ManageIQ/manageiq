module Ancestry
  module InstanceMethods
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
