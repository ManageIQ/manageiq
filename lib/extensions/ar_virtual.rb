module VirtualIncludes
  extend ActiveSupport::Concern

  included do
    class_attribute :_virtual_includes, :instance_accessor => false
    self._virtual_includes = {}
  end

  module ClassMethods
    def virtual_includes(name)
      load_schema
      _virtual_includes[name.to_s]
    end

    private

    def define_virtual_include(name, uses)
      self._virtual_includes = _virtual_includes.merge(name => uses)
    end
  end
end

module VirtualArel
  extend ActiveSupport::Concern

  included do
    class_attribute :_virtual_arel, :instance_accessor => false
    self._virtual_arel = {}
  end

  module ClassMethods
    def arel_attribute(column_name, arel_table = self.arel_table)
      load_schema
      if virtual_attribute?(column_name) && !attribute_alias?(column_name)
        col = _virtual_arel[column_name.to_s]
        col.call(arel_table) if col
      else
        super
      end
    end

    # supported by sql if
    # - it is an attribute alias
    # - it is an attribute that is non virtual
    # - it is an attribute that is virtual and has arel defined
    def attribute_supported_by_sql?(name)
      load_schema
      try(:attribute_alias?, name) ||
        (has_attribute?(name) && (!virtual_attribute?(name) || !!_virtual_arel[name.to_s]))
    end
    private

    def define_virtual_arel(name, arel)
      self._virtual_arel = _virtual_arel.merge(name => arel)
    end
  end
end

module VirtualDelegates
  extend ActiveSupport::Concern

  included do
    class_attribute :virtual_delegates_to_define, :instance_accessor => false
    self.virtual_delegates_to_define = {}
  end

  module ClassMethods

    #
    # Definition
    #

    def virtual_delegate(*methods)
      options = methods.extract_options!
      unless (to = options[:to])
        raise ArgumentError, 'Delegation needs an association. Supply an options hash with a :to key as the last argument (e.g. delegate :hello, to: :greeter).'
      end

      to = to.to_s
      if to.include?(".") && methods.size > 1
        raise ArgumentError, 'Delegation only supports specifying a method name when defining a single virtual method'
      end

      if to.count(".") > 1
        raise ArgumentError, 'Delegation needs a single association. Supply an option hash with a :to key with only 1 period (e.g. delegate :hello, to: "greeter.greeting")'
      end

      allow_nil = options[:allow_nil]
      default = options[:default]

      # put method entry per method name.
      # This better supports reloading of the class and changing the definitions
      methods.each do |method|
        method_prefix = virtual_delegate_name_prefix(options[:prefix], to)
        method_name = "#{method_prefix}#{method}"
        if to.include?(".") # to => "target.method"
          to, method = to.split(".")
          options[:to] = to
        end

        define_delegate(method_name, method, :to => to, :allow_nil => allow_nil, :default => default)

        self.virtual_delegates_to_define =
          virtual_delegates_to_define.merge(method_name => [method, options])
      end
    end

    private

    # define virtual_attribute for delegates
    #
    # this is called at schema load time (and not at class definition time)
    #
    # @param  method_name [Symbol] name of the attribute on the source class to be defined
    # @param  col [Symbol] name of the attribute on the associated class to be referenced
    # @option options :to [Symbol] name of the association from the source class to be referenced
    # @option options :arel [Proc] (optional and not common)
    # @option options :uses [Array|Symbol|Hash] sql includes hash. (default: to)
    def define_virtual_delegate(method_name, col, options)
      unless (to = options[:to]) && (to_ref = reflection_with_virtual(to.to_s))
        raise ArgumentError, 'Delegation needs an association. Supply an options hash with a :to key as the last argument (e.g. delegate :hello, to: :greeter).'
      end

      col = col.to_s
      type = to_ref.klass.type_for_attribute(col)
      raise "unknown attribute #{to}##{col} referenced in #{name}" unless type
      arel = virtual_delegate_arel(col, to_ref)
      define_virtual_attribute(method_name, type, :uses => (options[:uses] || to), :arel => arel)
    end

    # see activesupport module/delegation.rb
    def define_delegate(method_name, method, to: nil, allow_nil: nil, default: nil)
      location = caller_locations(2, 1).first
      file, line = location.path, location.lineno

      # Attribute writer methods only accept one argument. Makes sure []=
      # methods still accept two arguments.
      definition = (method =~ /[^\]]=$/) ? 'arg' : '*args, &block'
      default = default ? " || #{default.inspect}" : nil
      # The following generated method calls the target exactly once, storing
      # the returned value in a dummy variable.
      #
      # Reason is twofold: On one hand doing less calls is in general better.
      # On the other hand it could be that the target has side-effects,
      # whereas conceptually, from the user point of view, the delegator should
      # be doing one call.
      if allow_nil
        method_def = <<-METHOD
          def #{method_name}(#{definition})
            return self[:#{method_name}]#{default} if has_attribute?(:#{method_name})
            _ = #{to}
            if !_.nil? || nil.respond_to?(:#{method})
              _.#{method}(#{definition})
            end#{default}
          end
        METHOD
      else
        exception = %(raise Module::DelegationError, "#{self}##{method_name} delegated to #{to}.#{method}, but #{to} is nil: \#{self.inspect}")

        method_def = <<-METHOD
          def #{method_name}(#{definition})
            return self[:#{method_name}]#{default} if has_attribute?(:#{method_name})
            _ = #{to}
            _.#{method}(#{definition})#{default}
          rescue NoMethodError => e
            if _.nil? && e.name == :#{method}
              #{exception}
            else
              raise
            end
          end
        METHOD
      end
      method_def = method_def.split("\n").map(&:strip).join(';')
      module_eval(method_def, file, line)
    end

    def virtual_delegate_name_prefix(prefix, to)
      "#{prefix == true ? to : prefix}_" if prefix
    end

    # @param col [String] attribute name
    # @param to_ref [Association] association from source class to target association
    # @return [Proc] lambda to return arel that selects the attribute in a sub-query
    # @return [Nil] if the attribute (col) can not be represented in sql.
    #
    # To generate a proc, the following cases must happen:
    #   - the column has sql (virtual_column with arel OR real sql attribute)
    #   - the association has sql representation (a real association has sql)
    #   - the association is to a single record (has_one or belongs_to)
    #
    #   See select_from_alias for examples

    def virtual_delegate_arel(col, to_ref)
      # ensure the column has sql and the association is reachable via sql
      # There is currently no way to propagate sql over a virtual association
      if to_ref.klass.arel_attribute(col) && reflect_on_association(to_ref.name)
        if to_ref.macro == :has_one
          lambda do |t|
            src_model_id = arel_attribute(to_ref.association_primary_key, t)
            VirtualDelegates.select_from_alias(to_ref, col, to_ref.foreign_key, src_model_id) do |arel|
              arel.limit = 1
            end
          end
        elsif to_ref.macro == :belongs_to
          lambda do |t|
            src_model_id = arel_attribute(to_ref.foreign_key, t)
            VirtualDelegates.select_from_alias(to_ref, col, to_ref.active_record_primary_key, src_model_id)
          end
        end
      end
    end
  end

  # select_from_alias: helper method for virtual_delegate_arel to construct the sql
  # see also virtual_delegate_arel
  #
  # @param to_ref [Association] association from source class to target association
  # @param col [String] attribute name
  # @param to_model_col_name [String]
  # @param src_model_id [Arel::Attribute]
  # @return [Arel::Node] Arel representing the sql for this join
  #
  # example
  #
  #   for the given belongs_to class definition:
  #
  #     class Vm
  #       belongs_to :hosts #, :foreign_key => :host_id, :primary_key => :id
  #       virtual_delegate :name, :to => :host, :prefix => true, :allow_nil => true
  #     end
  #
  #   The virtual_delegate calls:
  #
  #     virtual_delegate_arel("name", Vm.reflection_with_virtual(:host))
  #
  #   which calls:
  #
  #     select_from_alias(Vm.reflection_with_virtual(:host), "name", "id", Vm.arel_table[:host_id])
  #
  #   which produces the sql:
  #
  #     SELECT to_model[col] from to_model where to_model[to_model_col_name] = src_model_table[:src_model_id]
  #     (SELECT "hosts"."name" FROM "hosts" WHERE "hosts"."id" = "vms"."host_id")
  #
  #   ----
  #
  #   for the given has_one class definition
  #
  #     class Host
  #       has_one :hardware
  #       virtual_delegate :name, :to => :hardware, :prefix => true, :allow_nil => true
  #     end
  #
  #   The virtual_delegate calls:
  #
  #     virtual_delegate_arel("name", Host.reflection_with_virtual(:hardware))
  #
  #   which at runtime will call select_from_alias:
  #
  #     select_from_alias(Host.reflection_with_virtual(:hardware), "name", "host_id", Host.arel_table[:id])
  #
  #   which produces the sql (ala arel):
  #
  #     #select to_model[col] from to_model where to_model[to_model_col_name] = src_model_table[:src_model_id]
  #     (SELECT "hardwares"."name" FROM "hardwares" WHERE "hardwares"."host_id" = "hosts"."id")
  #
  #   ----
  #
  #   for the given self join class definition:
  #
  #     class Vm
  #       belongs_to :src_template, :class => Vm
  #       virtual_delegate :name, :to => :src_template, :prefix => true, :allow_nil => true
  #     end
  #
  #   The virtual_delegate calls:
  #
  #     virtual_delegate_arel("name", Vm.reflection_with_virtual(:src_template))
  #
  #   which calls:
  #
  #     select_from_alias(Vm.reflection_with_virtual(:src_template), "name", "src_template_id", Vm.arel_table[:id])
  #
  #   which produces the sql:
  #
  #     #select to_model[col] from to_model where to_model[to_model_col_name] = src_model_table[:src_model_id]
  #     (SELECT "vms_sub"."name" FROM "vms" AS "vms_ss" WHERE "vms_ss"."id" = "vms"."src_template_id")
  #

  def self.select_from_alias(to_ref, col, to_model_col_name, src_model_id)
    query = if to_ref.scope
              to_ref.klass.instance_exec(nil, &to_ref.scope)
            else
              to_ref.klass.all
            end

    to_table    = select_from_alias_table(to_ref.klass, src_model_id.relation)
    to_model_id = to_ref.klass.arel_attribute(to_model_col_name, to_table)
    to_column   = to_ref.klass.arel_attribute(col, to_table)
    arel        = query.except(:select).select(to_column).arel
                       .from(to_table)
                       .where(to_model_id.eq(src_model_id))

    yield arel if block_given?

    Arel.sql("(#{arel.to_sql})")
  end

  # determine table reference to use for a sub query
  #
  # typically to_table is just the table used for the to_ref
  # but if it is a self join, then it will also have an alias
  def self.select_from_alias_table(to_klass, src_relation)
    to_table = to_klass.arel_table
    # if a self join, alias the second table to a different name
    if to_table.table_name == src_relation.table_name
      # use a dup to not modify the primary table in the model
      to_table = to_table.dup
      # use a table alias to not conflict with table name in the primary query
      to_table.table_alias = "#{to_table.table_name}_sub"
    end
    to_table
  end
end

module VirtualAttributes
  extend ActiveSupport::Concern
  include VirtualIncludes
  include VirtualArel
  include VirtualDelegates

  module Type
    # TODO: do we actually need symbol types?
    class Symbol < ActiveRecord::Type::String
      def type; :symbol; end
    end

    class StringSet < ActiveRecord::Type::Value
      def type; :string_set; end
    end

    class NumericSet < ActiveRecord::Type::Value
      def type; :numeric_set; end
    end
  end

  ActiveRecord::Type.register(:numeric_set, Type::NumericSet)
  ActiveRecord::Type.register(:string_set, Type::StringSet)
  ActiveRecord::Type.register(:symbol, Type::Symbol)

  included do
    class_attribute :virtual_attributes_to_define, :instance_accessor => false
    self.virtual_attributes_to_define = {}
  end

  module ClassMethods

    #
    # Definition
    #

    # Compatibility method: `virtual_attribute` is a more accurate name
    def virtual_column(name, type_or_options, **options)
      if type_or_options.kind_of?(Hash)
        options = options.merge(type_or_options)
        type = options.delete(:type)
      else
        type = type_or_options
      end

      virtual_attribute(name, type, **options)
    end

    def virtual_attribute(name, type, **options)
      name = name.to_s
      reload_schema_from_cache

      self.virtual_attributes_to_define =
        virtual_attributes_to_define.merge(name => [type, options])
    end

    #
    # Introspection
    #

    def virtual_attribute?(name)
      load_schema
      has_attribute?(name) && (
        !respond_to?(:column_for_attribute) ||
        column_for_attribute(name).kind_of?(ActiveRecord::ConnectionAdapters::NullColumn)
      )
    end

    def virtual_attribute_names
      if respond_to?(:column_names)
        attribute_names - column_names
      else
        attribute_names
      end
    end

    def attributes_builder # :nodoc:
      unless defined?(@attributes_builder) && @attributes_builder
        defaults = _default_attributes.except(*(column_names - [primary_key]))
        # change necessary for rails 5.0 and 5.1 - (changed/introduced in https://github.com/rails/rails/pull/31894)
        defaults = defaults.except(*virtual_attribute_names)
        # end change
        @attributes_builder = ActiveRecord::AttributeSet::Builder.new(attribute_types, defaults)
      end
      @attributes_builder
    end

    private

    def load_schema!
      super

      virtual_attributes_to_define.each do |name, (type, options)|
        type = type.call if type.respond_to?(:call)
        type = ActiveRecord::Type.lookup(type, **options.except(:uses, :arel)) if type.kind_of?(Symbol)

        define_virtual_attribute(name, type, **options.slice(:uses, :arel))
      end

      virtual_delegates_to_define.each do |method_name, (method, options)|
        define_virtual_delegate(method_name, method, options)
      end
    end

    def define_virtual_attribute(name, cast_type, uses: nil, arel: nil)
      attribute_types[name] = cast_type
      define_virtual_include(name, uses) if uses
      define_virtual_arel(name, arel) if arel
    end
  end
end

module VirtualReflections
  extend ActiveSupport::Concern
  include VirtualIncludes

  module ClassMethods

    #
    # Definition
    #

    def virtual_has_one(name, options = {})
      uses = options.delete(:uses)
      reflection = ActiveRecord::Associations::Builder::HasOne.build(self, name, nil, options)
      add_virtual_reflection(reflection, name, uses, options)
    end

    def virtual_has_many(name, options = {})
      define_method("#{name.to_s.singularize}_ids") do
        records = send(name)
        records.respond_to?(:ids) ? records.ids : records.collect(&:id)
      end
      uses = options.delete(:uses)
      reflection = ActiveRecord::Associations::Builder::HasMany.build(self, name, nil, options)
      add_virtual_reflection(reflection, name, uses, options)
    end

    def virtual_belongs_to(name, options = {})
      uses = options.delete(:uses)
      reflection = ActiveRecord::Associations::Builder::BelongsTo.build(self, name, nil, options)
      add_virtual_reflection(reflection, name, uses, options)
    end

    def virtual_reflection?(name)
      virtual_reflections.key?(name.to_sym)
    end

    def virtual_reflection(name)
      virtual_reflections[name.to_sym]
    end

    #
    # Introspection
    #

    def virtual_reflections
      (virtual_fields_base? ? {} : superclass.virtual_reflections).merge(_virtual_reflections)
    end

    def reflections_with_virtual
      reflections.symbolize_keys.merge(virtual_reflections)
    end

    def reflection_with_virtual(association)
      virtual_reflection(association) || reflect_on_association(association)
    end

    def follow_associations(association_names)
      association_names.inject(self) { |klass, name| klass.try!(:reflect_on_association, name).try!(:klass) }
    end

    def follow_associations_with_virtual(association_names)
      association_names.inject(self) { |klass, name| klass.try!(:reflection_with_virtual, name).try!(:klass) }
    end

    # invalid associations return a nil
    # real reflections are followed
    # a virtual association will stop the traversal
    # @returns [nil, Array<Relation>]
    def collect_reflections(association_names)
      klass = self
      association_names.each_with_object([]) do |name, ret|
        reflection = klass.reflect_on_association(name)
        if reflection.nil?
          if klass.reflection_with_virtual(name)
            break(ret)
          else
            break
          end
        end
        klass = reflection.klass
        ret << reflection
      end
    end

    def collect_reflections_with_virtual(association_names)
      klass = self
      association_names.collect do |name|
        reflection = klass.reflection_with_virtual(name) || break
        klass = reflection.klass
        reflection
      end
    end

    private

    def add_virtual_reflection(reflection, name, uses, _options)
      raise ArgumentError, "macro must be specified" unless reflection
      reset_virtual_reflection_information
      _virtual_reflections[name.to_sym] = reflection
      define_virtual_include(name.to_s, uses)
    end

    def reset_virtual_reflection_information
    end

    def _virtual_reflections
      @virtual_reflections ||= {}
    end
  end
end

module VirtualFields
  extend ActiveSupport::Concern
  include VirtualAttributes
  include VirtualReflections

  module NonARModels
    def dangerous_attribute_method?(_); false; end

    def generated_association_methods; self; end

    def add_autosave_association_callbacks(*_args); self; end

    def belongs_to_required_by_default; false; end
  end

  included do
    unless respond_to?(:dangerous_attribute_method?)
      extend NonARModels
    end
  end

  module ClassMethods
    def virtual_fields_base?
      !(superclass < VirtualFields)
    end

    def virtual_field?(name)
      virtual_attribute?(name) || virtual_reflection?(name)
    end

    def remove_virtual_fields(associations)
      case associations
      when String, Symbol
        virtual_field?(associations) ? nil : associations
      when Array
        associations.collect { |association| remove_virtual_fields(association) }.compact
      when Hash
        associations.each_with_object({}) do |(parent, child), h|
          next if virtual_field?(parent)
          reflection = reflect_on_association(parent.to_sym)
          h[parent] = reflection.options[:polymorphic] ? nil : reflection.klass.remove_virtual_fields(child) if reflection
        end
      else
        associations
      end
    end
  end
end

#
# Class extensions
#

# this patch is no longer necessary for 5.2
require "active_record/attribute"
module ActiveRecord
  # This is a bug in rails 5.0 and 5.1, but it is made much worse by virtual attributes
  class Attribute
    def with_value_from_database(value)
      # self.class.from_database(name, value, type)
      initialized? ? self.class.from_database(name, value, type) : self
    end
  end
end

module ActiveRecord
  class Base
    include VirtualFields
  end

  module Associations
    class Preloader
      prepend Module.new {
        def preloaders_for_one(association, records, scope)
          klass_map = records.compact.group_by(&:class)

          loaders = klass_map.keys.group_by { |klass| klass.virtual_includes(association) }.flat_map do |virtuals, klasses|
            subset = klasses.flat_map { |klass| klass_map[klass] }
            preload(subset, virtuals)
          end

          records_with_association = klass_map.select { |k, rs| k.reflect_on_association(association) }.flat_map { |k, rs| rs }
          if records_with_association.any?
            loaders.concat(super(association, records_with_association, scope))
          end

          loaders
        end
      }
    end

    # FIXME: Hopefully we can get this into Rails core so this is no longer
    # required in our codebase, but the rule that are broken here are mostly
    # due to the style of the Rails codebase conflicting with our own.
    # Ignoring them to avoid noise in RuboCop, but allow us to keep the same
    # syntax from the original codebase.
    #
    # rubocop:disable Style/BlockDelimiters, Layout/SpaceAfterComma, Style/HashSyntax
    # rubocop:disable Layout/AlignHash, Metrics/AbcSize, Metrics/MethodLength
    class JoinDependency
      def instantiate(result_set, aliases)
        primary_key = aliases.column_alias(join_root, join_root.primary_key)

        seen = Hash.new { |i, object_id|
          i[object_id] = Hash.new { |j, child_class|
            j[child_class] = {}
          }
        }

        model_cache = Hash.new { |h,klass| h[klass] = {} }
        parents = model_cache[join_root]
        column_aliases = aliases.column_aliases(join_root)

        # New Code
        #
        # This monkey patches the ActiveRecord::Associations::JoinDependency to
        # include columns into the main record that might have been added
        # through a `select` clause.
        #
        # This can be seen with the following:
        #
        #   Vm.select(Vm.arel_table[Arel.star]).select(:some_vm_virtual_col)
        #     .includes(:tags => {}).references(:tags => {})
        #
        # Which will produce a SQL SELECT statement kind of like this:
        #
        #   SELECT "vms".*,
        #          (<virtual_attribute_arel>) AS some_vm_virtual_col,
        #          "vms"."id"      AS t0_r0
        #          "vms"."vendor"  AS t0_r1
        #          "vms"."format"  AS t0_r1
        #          "vms"."version" AS t0_r1
        #          ...
        #          "tags"."id"     AS t1_r0
        #          "tags"."name"   AS t1_r1
        #
        # This is because rails is trying to reduce the number of queries
        # needed to fetch all of the records in the include, so it grabs the
        # columns for both of the tables together to do it.  Unfortuantely (or
        # fortunately... depending on how you look at it), it does not remove
        # any `.select` columns from the query that is run in the process, so
        # that is brought along for the ride, but never used when this method
        # instanciates the objects.
        #
        # The "New Code" here simply also instanciates any extra rows that
        # might have been included in the select (virtual_columns) as well and
        # brought back with the result set.
        unless result_set.empty?
          join_dep_keys         = aliases.columns.map(&:right)
          join_root_aliases     = column_aliases.map(&:first)
          additional_attributes = result_set.first.keys
                                            .reject { |k| join_dep_keys.include?(k) }
                                            .reject { |k| join_root_aliases.include?(k) }
                                            .map    { |k| [k, k] }
          column_aliases += additional_attributes
        end
        # End of New Code

        message_bus = ActiveSupport::Notifications.instrumenter

        payload = {
          record_count: result_set.length,
          class_name: join_root.base_klass.name
        }

        message_bus.instrument('instantiation.active_record', payload) do
          result_set.each { |row_hash|
            parent_key = primary_key ? row_hash[primary_key] : row_hash
            parent = parents[parent_key] ||= join_root.instantiate(row_hash, column_aliases)
            construct(parent, join_root, row_hash, result_set, seen, model_cache, aliases)
          }
        end

        parents.values
      end
      # rubocop:enable Style/BlockDelimiters, Layout/SpaceAfterComma, Style/HashSyntax
      # rubocop:enable Layout/AlignHash, Metrics/AbcSize, Metrics/MethodLength
    end
  end

  class Relation
    def without_virtual_includes
      filtered_includes = includes_values && klass.remove_virtual_fields(includes_values)
      if filtered_includes != includes_values
        spawn.tap { |other| other.includes_values = filtered_includes }
      else
        self
      end
    end

    include Module.new {
      # From ActiveRecord::FinderMethods
      def find_with_associations
        real = without_virtual_includes
        return super if real.equal?(self)

        recs = real.find_with_associations
        MiqPreloader.preload(recs, preload_values + includes_values) if includes_values

        recs
      end

      # From ActiveRecord::QueryMethods
      def select(*fields)
        return super if block_given? || fields.empty?
        # support virtual attributes by adding an alias to the sql phrase for the column
        # it does not add an as() if the column already has an as
        # this code is based upon _select()
        fields.flatten!
        fields.map! do |field|
          if virtual_attribute?(field) && (arel = klass.arel_attribute(field)) && arel.respond_to?(:as)
            arel.as(field.to_s)
          else
            field
          end
        end
        # end support virtual attributes
        super
      end

      # From ActiveRecord::Calculations
      def calculate(operation, attribute_name)
        # work around 1 until https://github.com/rails/rails/pull/25304 gets merged
        # This allows attribute_name to be a virtual_attribute
        if (arel = klass.arel_attribute(attribute_name)) && virtual_attribute?(attribute_name)
          attribute_name = arel
        end
        # end work around 1

        # allow calculate to work when including a virtual attribute
        real = without_virtual_includes
        return super if real.equal?(self)

        real.calculate(operation, attribute_name)
      end
    }
  end
end
