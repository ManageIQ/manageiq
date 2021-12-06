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

  private

  def references(collection, manager_ref: :ems_ref)
    target.manager_refs_by_association&.dig(collection, manager_ref)&.to_a&.compact || []
  end

  def add_target!(association, manager_ref, options = {})
    return if manager_ref.blank?

    manager_ref = {:ems_ref => manager_ref} unless manager_ref.kind_of?(Hash)
    target.add_target(:association => association, :manager_ref => manager_ref, :options => options)
  end
end
