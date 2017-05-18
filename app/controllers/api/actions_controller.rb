module Api
  class ActionsController < BaseController
    def create_resource(type, id, data = {})
      data["options"] = data["options"].deep_symbolize_keys if data["options"]
      super(type, id, data)
    end

    def edit_resource(type, id = nil, data = {})
      data["options"] = data["options"].deep_symbolize_keys if data["options"]
      super(type, id, data)
    end
  end
end
