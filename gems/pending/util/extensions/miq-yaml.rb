require 'yaml'

# The following fixes a bug in Ruby where YAML dumping a subclass of Hash
#   with instance variables does not actually dump those instance variables.

module Psych
  module Visitors
    class ToRuby
      SHOVEL      = '<<'
      IVAR_MARKER = '__iv__'
      def revive_hash(hash, o)
        o.children.each_slice(2) do |k, v|
          key = accept(k)

          if key == SHOVEL
            case v
            when Nodes::Alias
              hash.merge! accept(v)
            when Nodes::Sequence
              accept(v).reverse_each do |value|
                hash.merge! value
              end
            else
              hash[key] = accept(v)
            end

          # We need to migrate all old YAML before we can remove this
          #### Reapply the instance variables, see https://github.com/tenderlove/psych/issues/43
          elsif key.to_s.start_with?(IVAR_MARKER)
            hash.instance_variable_set(key.to_s[6..-1], accept(v))

          else
            hash[key] = accept(v)
          end
        end
        hash
      end
    end
  end
end
