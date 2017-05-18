module Api
  class AlertDefinitionsController < BaseController
    REQUIRED_FIELDS = %w(description db expression options).freeze

    def create_resource(type, id, data = {})
      assert_id_not_specified(data, type)
      assert_all_required_fields_exists(data, type, REQUIRED_FIELDS)
      begin
        data["expression"] = MiqExpression.new(data["expression"])
        data["enabled"] = true if data["enabled"].nil?
        super(type, id, data)
      rescue => err
        raise BadRequestError, "Failed to create a new alert definition - #{err}"
      end
    end

    def edit_resource(type, id = nil, data = {})
      raise BadRequestError, "Must specify an id for editing a #{type} resource" unless id
      begin
        data["expression"] = MiqExpression.new(data["expression"]) if data["expression"]
        super(type, id, data)
      rescue => err
        raise BadRequestError, "Failed to update alert definition - #{err}"
      end
    end
  end
end
