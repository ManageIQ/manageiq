# This is a form of an AR Model. But the distinction is this is a model based upon an ActiveRecord scope (aar_scope)
# Essentially, this delegates all calls to the scope.
# It may be easier to understand by looking at an implementation like InfraManager::VmOrTemplate
class ActsAsArScope < ActsAsArModel
  class << self
    # Standard query methods are delegated to the core active record classes
    delegate :includes, :references, :eager_load, :preload, :limit, :order, :offset, :select, :where, :to => :aar_scope
    delegate :find, :first, :last, :find_by_id, :find_by, :count, :all, :to => :aar_scope

    delegate :klass, :to => :aar_scope, :prefix => true
    delegate :table_name, :reflections, :to => :aar_scope_klass
    delegate :virtual_reflections, :to => :aar_scope_klass
  end

  def self.aar_scope
    raise NotImplementedError, _("find must be implemented in a subclass")
  end

  # TODO: goal is for this to be false
  def self.instances_are_derived?
    true
  end
end
