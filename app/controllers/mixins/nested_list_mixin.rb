module Mixins
  module NestedListMixin
    def show_nested
      parent_table = params[:parent_collection]
      parent_id = from_cid(params[:parent_id])

      parent_controller = "#{parent_table}_controller".camelcase.constantize
      parent_model = controller_to_model(parent_controller)
      parent_record = identify_record(parent_id, parent_model)

      return render :json => {
        :parent_table => parent_table,
        :parent_id => parent_id,
        :my_table => self.class.table_name,
        :my_model => controller_to_model.name,
        :parent_record => parent_record,
        :parent_model => parent_model.name,
      } if params[:debug]

      @display = 'main'
      nested_list(self.class.table_name, controller_to_model, parent_table, parent_record)
      #show_list
      render :action => 'show_list' unless performed?
    end

  end
end
