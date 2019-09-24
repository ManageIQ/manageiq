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
      join_key = association.join_keys
      target_klass.where(join_key.key.to_sym => records.select(join_key.foreign_key.to_sym))
    end
  end
end
