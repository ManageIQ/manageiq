class ManagerRefresh::Inventory::Target
  # @param [ApplicationRecord] root
  def initialize(root)
    @root = root
  end

  def collections
    @collections ||= {}
  end

  def inventory_collections
    @collections.values
  end
end
