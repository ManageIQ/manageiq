module Menu
  Section = Struct.new(:id, :name, :items, :type) do
    def initialize(an_id, name, items = [], type = :default)
      super
    end

    def features
      Array(items).collect(&:feature).compact
    end
  end
end

