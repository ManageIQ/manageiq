class ManagerRefresh::Inventory::Parser
  attr_accessor :collector
  attr_accessor :target

  def parse
    raise NotImplementedError, _("must be implemented in a subclass")
  end
end
