module MiqPreloader
  def self.preload(records, associations, preload_scope = nil)
    preloader = ActiveRecord::Associations::Preloader.new
    preloader.preload(records, associations, preload_scope)
  end

  # it will load records and their associations, and return the children
  #
  # instead of N+1:
  #   orchestration_stack.subtree.flat_map(&:direct_vms)
  # use instead:
  #   preload_and_map(orchestration_stack.subtree, :direct_vms)
  def self.preload_and_map(records, association)
    Array.wrap(records).tap { |recs| MiqPreloader.preload(recs, association) }.flat_map(&association)
  end

  # @param records [ActiveRecord::Base, Array<ActiveRecord::Base>, Object, Array<Object>]
  # @param association [String] an association on records
  def self.preload_and_scope(records, association_name)
    records = Array.wrap(records) unless records.kind_of?(Enumerable)
    active_record_klass = records.respond_to?(:klass) ? records.klass : records.first.class
    association = active_record_klass.reflect_on_association(association_name)

    return preload_and_map(records, association_name) unless association

    target_klass = association.klass
    if (inverse_association = association.inverse_of)
      target_klass.where(inverse_association.name.to_sym => records).where(association.scope)
    else # assume it is a belongs_to
      join_key = association.join_keys(target_klass)
      target_klass.where(join_key.key.to_sym => records.select(join_key.foreign_key.to_sym))
    end
  end

  # Allows having a polymorphic preloader, but then having class specific
  # preloaders fire for the loaded polymorphic classes.
  #
  # @param records [ActiveRecord::Relation] collection of activerecord objects to preload into
  # @param associations [Symbol|String|Array|Hash] association(s) to load (see .includes for examples)
  # @param class_preloaders [Hash] keys are Classes, and values are associations for that polymorphic type
  #
  # Values for class_preloaders can either be an Array of two (args for sub
  # preloader relationships), or an arel statement, which is the arel scope to
  # execute for that specific class only (no sub relationships preloaded.
  #
  # Example:
  #
  #   irb> tree = ExtManagementSystem.last.fulltree_rels_arranged(:except_type => "VmOrTemplate")
  #   irb> records = Relationship.flatten_arranged_rels(tree)
  #   irb> hosts_scope = Host.select(Host.arel_table[Arel.star], :v_total_vms)
  #   irb> preloaders_per_class = { EmsCluster => [:hosts, hosts_scope], Host => hosts_scope }
  #   irb> MiqPreloader.polymorphic_preload_for_child_classes(records, nil, preloaders_per_class)
  #
  # Note:  Class's .base_class are favored over their specific class
  #
  def self.polymorphic_preload_for_child_classes(records, associations, class_preloaders = {})
    preloader = ActiveRecord::Associations::Preloader.new
    preloader.extend(Module.new {
      attr_accessor :class_specific_preloaders

      # DIRTY HACK... but hey... at least I am just isolating it to this method
      # right...
      #
      # Everyone else: "No Nick... just no..."

      # Updated form from ar_virtual.rb, and merged with the code originally in
      # ActiveRecord.  If the code in ar_virtual.rb is changed, this should
      # probably also be updated.
      def preloaders_for_one(association, records, scope)
        klass_map = records.compact.group_by(&:class)

        loaders = klass_map.keys.group_by { |klass| klass.virtual_includes(association) }.flat_map do |virtuals, klasses|
          subset = klasses.flat_map { |klass| klass_map[klass] }
          preload(subset, virtuals)
        end

        records_with_association = klass_map.select { |k, rs| k.reflect_on_association(association) }.flat_map { |k, rs| rs }
        if records_with_association.any?
          # This injects the original code from preloaders_for_one from
          # ActiveRecord so we can add our own `if` in the middle of it.  The
          # positive part of the `if` is the only portion of this that has
          # changed, and the code copied is within the `loaders.concat`.
          loaders.concat(grouped_records(association, records_with_association).flat_map do |reflection, klasses|
            klasses.map do |rhs_klass, rs|
              base_klass = rhs_klass.base_class if rhs_klass.respond_to?(:base_class)

              # Start of new code (1)
              class_preloader = (class_specific_preloaders[base_klass] || class_specific_preloaders[rhs_klass])
              loader_klass    = preloader_for(reflection, rs, rhs_klass)

              loader = if class_preloader.kind_of?(ActiveRecord::Relation)
                         loader_klass.new(rhs_klass, rs, reflection, class_preloader)
                       else
                         loader_klass.new(rhs_klass, rs, reflection, scope)
                       end
              # End of new code (1)

              loader.run self

              # Start of new code (2)
              if class_preloader.kind_of?(Array) && class_preloader.count == 2
                [loader, MiqPreloader.preload(loader.preloaded_records, class_preloader[0], class_preloader[1])]
              else
                loader
              end
              # End of new code (2)
            end
          end)
        end

        loaders
      end
    })
    preloader.class_specific_preloaders = class_preloaders || {}

    preloader.preload(records, associations, nil)
  end
end
