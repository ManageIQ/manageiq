module Mixins
  module CheckedIdMixin
    def get_checked_item_id(params)
      if params[:id]
        checked_item_id = params[:id]
      else
        checked_items = find_checked_items
        checked_item_id = checked_items[0] if checked_items.length == 1
      end
      checked_item_id
    end
  end
end
