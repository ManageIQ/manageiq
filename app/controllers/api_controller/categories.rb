class ApiController
  module Categories
    #
    # Categories Collection Supporting Methods
    #
    #
    def show_categories
      @req[:additional_attributes] = %w(name)
      show_generic(:categories)
    end

    def edit_resource_categories(type, id, data = {})
      raise ApiController::Forbidden if Category.find(id).read_only?
      edit_resource(type, id, data)
    end

    def delete_resource_categories(type, id, data = {})
      raise ApiController::Forbidden if Category.find(id).read_only?
      delete_resource(type, id, data)
    end
  end
end
