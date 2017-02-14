class ManagerRefresh::Inventory::Collector
  attr_accessor :manager, :target

  # @param manager [ManageIQ::Providers::BaseManager] A manager object
  # @param target [ActiveRecord|Hash] A refresh Target object
  def initialize(manager, target)
    @manager = manager
    @target  = target
  end

  def options
    @options ||= Settings.ems_refresh[manager.class.ems_type]
  end
end
