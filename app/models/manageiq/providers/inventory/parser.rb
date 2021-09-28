class ManageIQ::Providers::Inventory::Parser
  attr_accessor :collector
  attr_accessor :persister

  include Vmdb::Logging

  def parse
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  # @return [Config::Options] Options for the manager type
  def options
    @options ||= Settings.ems_refresh[persister.manager.class.ems_type]
  end
end
