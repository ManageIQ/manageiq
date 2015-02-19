module Menu
  Section = Struct.new(:id, :name, :items, :type, :after) do
    def initialize(an_id, name, items = [], type = :default, after = nil)
      super
    end

    def features
      Array(items).collect(&:feature).compact
    end
  end
end
