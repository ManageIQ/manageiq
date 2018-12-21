class ManageIQ::Providers::Inventory::Parser
  attr_accessor :collector
  attr_accessor :persister

  include Vmdb::Logging

  def parse
    raise NotImplementedError, _("must be implemented in a subclass")
  end
end
