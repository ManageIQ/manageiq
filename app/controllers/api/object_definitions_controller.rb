module Api
  class ObjectDefinitionsController < BaseController
    def show
      object = fetch_object_definition(@req.c_id)
      render_resource :object_definitions, object
    end

    private

    def fetch_object_definition(id)
      klass = collection_class(:object_definitions)
      klass.find_by(:name => id) || klass.find(id)
    end
  end
end
