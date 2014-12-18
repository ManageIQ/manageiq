MenuSection = Struct.new(:id, :name, :items) do
  def features
    items.collect(&:feature).compact
  end
end

