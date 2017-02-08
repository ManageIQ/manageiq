class ManagerRefresh::Inventory::Collector
  attr_accessor :manager
  attr_accessor :target

  def initialize(manager, target)
    @manager = manager
    @target  = target
  end
end
