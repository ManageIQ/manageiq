module Menu
  class PolymorphItem < Item
    def name
      super.call
    end
  end
end
