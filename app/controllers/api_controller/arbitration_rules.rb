class ApiController
  module ArbitrationRules
    def create_resource_arbitration_rules(type, _id, data)
      attributes = validate_arbitration_rules(data)
      arbitration_rule = collection_class(type).create(attributes)
      if arbitration_rule.invalid?
        raise BadRequestError,
              "Failed to create a new virtual template - #{arbitration_rule.errors.full_messages.join(', ')}"
      end
      arbitration_rule
    end

    def edit_resource_arbitration_rules(type, id, data)
      attributes = validate_arbitration_rules(data)
      edit_resource(type, id, attributes)
    end

    private

    def validate_arbitration_rules(data)
      if data.key?('id') || data.key?('href')
        raise BadRequestError, 'Resource id or href should not be specified'
      end
      attributes = data.dup
      attributes['expression'] = MiqExpression.new(data['expression'])
      attributes
    end
  end
end
