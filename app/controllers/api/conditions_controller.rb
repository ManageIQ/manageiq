module Api
  class ConditionsController < BaseController
    def create_resource(type, id, data = {})
      assert_id_not_specified(data, type)
      begin
        data["expression"] = MiqExpression.new(data["expression"]) if data["expression"]
        super(type, id, data)
      rescue => err
        raise BadRequestError, "Failed to create a new condition - #{err}"
      end
    end

    def edit_resource(type, id = nil, data = {})
      raise BadRequestError, "Must specify an id for editing a #{type} resource" unless id
      begin
        data["expression"] = MiqExpression.new(data["expression"]) if data["expression"]
        super(type, id, data)
      rescue => err
        raise BadRequestError, "Failed to update condition - #{err}"
      end
    end
  end
end
