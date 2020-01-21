class ManageIQ::Providers::Inventory::Collector
  attr_reader :manager, :target

  include Vmdb::Logging

  # @param manager [ManageIQ::Providers::BaseManager] A manager object
  # @param refresh_target [Object] A refresh Target object
  def initialize(manager, refresh_target)
    @manager = manager
    @target  = refresh_target
  end

  def collect
    # placeholder for sub-classes to be able to collect inventory before parsing
  end

  # @return [Config::Options] Options for the manager type
  def options
    @options ||= Settings.ems_refresh[manager.class.ems_type]
  end
end
