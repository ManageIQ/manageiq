module MiqPreloader
  # If you want to preload an association on multiple records
  # or want to only load a subset of an association
  #
  # @example Preloading vms on a set of emses
  #   vms_scope = Vm.where(:ems_id => emses.id)
  #   preload(emses, :vms, vms_scope)
  #   emses.map { |ems| ems.vms } # cached - no queries
  #   vms_scope.first.ems # cached - the reversed association is cached
  #
  #  @example Programmatically determine the reverse association name
  #    Going from Ems#association(:vms) and going to Vm#association(:ems)
  #
  #   reverse_association_name = record.class.reflect_on_association(association).inverse_of.name
  #   reverse_association = result.association(reverse_association_name)
  #
  # @param record [relation|ActiveRecord::Base|Array[ActiveRecord::Base]]
  # @param association [Symbol|Hash|Array] name of the association(s)
  # @param preload_scope [Nil|relation] Relation of the records to be use for preloading
  #        For all but one case, default behavior is to use the association
  #        Alternatively a scope can be used.
  #        Currently an array does not work
  # @return [Array<ActiveRecord::Base>] records
  def self.preload(records, associations, preload_scope = nil)
    preloader = ActiveRecord::Associations::Preloader.new
    preloader.preload(records, associations, preload_scope)
  end

  # for a record, cache results. Also cache the children's links back
  # currently preload works for simple associations, but this is needed for reverse associations
  def self.preload_from_array(record, association_name, values)
    association = record.association(association_name.to_sym)
    values = Array.wrap(values)
    association.target = association.reflection.collection? ? values : values.first
    values.each { |value| association.set_inverse_instance(value) }
  end

  # it will load records and their associations, and return the children
  #
  # instead of N+1:
  #   orchestration_stack.subtree.flat_map(&:direct_vms)
  # use instead:
  #   preload_and_map(orchestration_stack.subtree, :direct_vms)
  #
  # @param records [ActiveRecord::Base, Array<ActiveRecord::Base>, Object, Array<Object>]
  # @param association [Symbol] name of the association
  def self.preload_and_map(records, association)
    Array.wrap(records).tap { |recs| MiqPreloader.preload(recs, association) }.flat_map(&association)
  end

  # @param records [ActiveRecord::Base, Array<ActiveRecord::Base>, Object, Array<Object>]
  # @param association_name [Symbol] Name of the association
  def self.preload_and_scope(records, association_name)
    records = Array.wrap(records) unless records.kind_of?(Enumerable)
    active_record_klass = records.respond_to?(:klass) ? records.klass : records.first.class
    association = active_record_klass.reflect_on_association(association_name)

    return preload_and_map(records, association_name) unless association

    target_klass = association.klass
    if (inverse_association = association.inverse_of)
      target_klass.where(inverse_association.name.to_sym => records).where(association.scope)
    else # assume it is a belongs_to
      target_klass.where(association.join_primary_key.to_sym => records.select(association.join_foreign_key.to_sym))
    end
  end
end
