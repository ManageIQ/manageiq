module Api
  class AlertDefinitionsController < BaseController
    REQUIRED_FIELDS = %w(description db expression options).freeze

    def create_resource(type, id, data = {})
      assert_id_not_specified(data, type)
      assert_all_required_fields_exists(data, type, REQUIRED_FIELDS)
      begin
        if data["expression_type"].present?
          if MiqAlert::ALLOWED_API_EXPRESSION_TYPES.include? data["expression_type"]
            data["expression_type"] == "hash" ? data["expression"].deep_symbolize_keys! : data["expression"] = MiqExpression.new(data["expression"])
            # Delete the following line once #15315 is merged
            data.delete("expression_type")
          else
            raise "Invalid expression type specified: #{data["expression_type"]}"
          end
        else
          data["expression"] = MiqExpression.new(data["expression"])
        end
        data["options"].deep_symbolize_keys!
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
