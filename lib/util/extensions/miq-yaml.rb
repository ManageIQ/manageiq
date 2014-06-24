require 'yaml'

# The following fixes a bug in Ruby where YAML dumping a subclass of Hash
#   with instance variables does not actually dump those instance variables.

module Psych
  module Visitors
    class YAMLTree
      def visit_Hash o
        tag      = o.class == ::Hash ? nil : "!ruby/hash:#{o.class}"
        implicit = !tag

        register(o, @emitter.start_mapping(nil, tag, implicit, Psych::Nodes::Mapping::BLOCK))

        o.each do |k,v|
          accept k
          accept v
        end

        #### Add in the instance variables, see https://github.com/tenderlove/psych/issues/43
        o.instance_variables.each do |m|
          accept "__iv__#{m}"
          accept o.instance_variable_get(m)
        end

        @emitter.end_mapping
      end
    end

    class ToRuby
      def revive_hash hash, o
        @st[o.anchor] = hash if o.anchor

          o.children.each_slice(2) { |k,v|
          key = accept(k)

          if key == '<<'
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

          #### Reapply the instance variables, see https://github.com/tenderlove/psych/issues/43
          elsif key.to_s[0..5] == "__iv__"
            hash.instance_variable_set(key.to_s[6..-1], accept(v))

          else
            hash[key] = accept(v)
          end

        }
        hash
      end
    end
  end
end

