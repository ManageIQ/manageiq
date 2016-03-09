module MiqPreloader
  def self.preload(records, associations, _options = {})
    preloader = ActiveRecord::Associations::Preloader.new
    preloader.preload(records, associations)
  end

  # it will load records and their associations, and return the children
  #
  # instead of N+1:
  #   orchestration_stack.subtree.flat_map(&:direct_vms)
  # use instead:
  #   preload_and_map(orchestration_stack.subtree, :direct_vms)
  def self.preload_and_map(records, association)
    records.to_a.tap { |recs| MiqPreloader.preload(recs, association) }.flat_map(&association)
  end
end
