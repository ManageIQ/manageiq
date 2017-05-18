class ManagerRefresh::Inventory::Collector
  attr_reader :manager, :target

  # @param manager [ManageIQ::Providers::BaseManager] A manager object
  # @param target [Object] A refresh Target object
  def initialize(manager, refresh_target)
    @manager = manager
    @target  = refresh_target
  end

  def options
    @options ||= Settings.ems_refresh[manager.class.ems_type]
  end
end
