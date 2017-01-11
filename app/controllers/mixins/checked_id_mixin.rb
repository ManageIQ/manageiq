module Mixins
  module CheckedIdMixin
    def checked_item_id(hash = params)
      return hash[:id] if hash[:id]

      checked_items = find_checked_items
      checked_items[0] if checked_items.length == 1
    end
  end
end
