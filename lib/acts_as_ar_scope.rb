# this is an extension to act as ar_model
# this allows a developer to formulate results as a scope
# all other behavior is handled from there
class ActsAsArScope < ActsAsArModel
  # user required to add aar_scope
  class << self
    delegate :includes, :references, :limit, :order, :offset, :select, :where, :to => :aar_scope
    delegate :find, :first, :last, :find_by_id, :find_by, :count, :to => :aar_scope

    delegate :klass, :to => :aar_scope, :prefix => true
    delegate :table_name, :reflections, :to => :aar_scope_klass
    delegate :_virtual_columns_hash, :virtual_reflections, :to => :aar_scope_klass
  end

  def self.all(*args)
    if args.empty? || args.size == 1 && args.first.respond_to?(:empty?) && args.first.empty?
      # avoid warnings
      aar_scope
    else
      aar_scope.all(*args)
    end
  end

  # TODO: goal is for this to be false
  def self.instances_are_derived?
    true
  end
end
