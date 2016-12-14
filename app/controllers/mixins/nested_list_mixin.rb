module Mixins
  module NestedListMixin
    def show_nested
      render :json => {
        :parent_collection => params[:parent_collection],
        :parent_id => from_cid(params[:parent_id]),
      }
    end

  end
end
