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

      if RUBY_PATCHLEVEL == 194
        def visit_Psych_Nodes_Mapping o
          return revive(Psych.load_tags[o.tag], o) if Psych.load_tags[o.tag]
          return revive_hash({}, o) unless o.tag

          case o.tag
          when /^!(?:str|ruby\/string)(?::(.*))?/, 'tag:yaml.org,2002:str'
            klass = resolve_class($1)
            members = Hash[*o.children.map { |c| accept c }]
            string = members.delete 'str'

            #### APPLY https://github.com/tenderlove/psych/commit/620fc6d749f0e94f7b433af9419927039ca1bfa4
            if klass
              string = klass.allocate.replace string
              register(o, string)
            end

            init_with(string, members.map { |k,v| [k.to_s.sub(/^@/, ''),v] }, o)
          when /^!ruby\/array:(.*)$/
            klass = resolve_class($1)
            list  = register(o, klass.allocate)

            members = Hash[o.children.map { |c| accept c }.each_slice(2).to_a]
            list.replace members['internal']

            members['ivars'].each do |ivar, v|
              list.instance_variable_set ivar, v
            end
            list
          when /^!ruby\/struct:?(.*)?$/
            klass = resolve_class($1)

            if klass
              s = register(o, klass.allocate)

              members = {}
              struct_members = s.members.map { |x| x.to_sym }
              o.children.each_slice(2) do |k,v|
                member = accept(k)
                value  = accept(v)
                if struct_members.include?(member.to_sym)
                  s.send("#{member}=", value)
                else
                  members[member.to_s.sub(/^@/, '')] = value
                end
              end
              init_with(s, members, o)
            else
              members = o.children.map { |c| accept c }
              h = Hash[*members]
              Struct.new(*h.map { |k,v| k.to_sym }).new(*h.map { |k,v| v })
            end

          when '!ruby/range'
            h = Hash[*o.children.map { |c| accept c }]
            register o, Range.new(h['begin'], h['end'], h['excl'])

          when /^!ruby\/exception:?(.*)?$/
            h = Hash[*o.children.map { |c| accept c }]

            e = build_exception((resolve_class($1) || Exception),
                                h.delete('message'))
            init_with(e, h, o)

          when '!set', 'tag:yaml.org,2002:set'
            set = Psych::Set.new
            @st[o.anchor] = set if o.anchor
            o.children.each_slice(2) do |k,v|
              set[accept(k)] = accept(v)
            end
            set

          when '!ruby/object:Complex'
            h = Hash[*o.children.map { |c| accept c }]
            register o, Complex(h['real'], h['image'])

          when '!ruby/object:Rational'
            h = Hash[*o.children.map { |c| accept c }]
            register o, Rational(h['numerator'], h['denominator'])

          when /^!ruby\/object:?(.*)?$/
            name = $1 || 'Object'
            obj = revive((resolve_class(name) || Object), o)
            obj

          when /^!map:(.*)$/, /^!ruby\/hash:(.*)$/
            revive_hash resolve_class($1).new, o

          else
            revive_hash({}, o)
          end
        end
      end
    end
  end
end

