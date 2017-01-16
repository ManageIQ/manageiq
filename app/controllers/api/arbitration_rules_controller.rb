module Api
  class ArbitrationRulesController < BaseController
    def create_resource(type, _id, data)
      attributes = build_rule_attributes(data)
      arbitration_rule = collection_class(type).create(attributes)
      if arbitration_rule.invalid?
        raise BadRequestError,
              "Failed to create a new virtual template - #{arbitration_rule.errors.full_messages.join(', ')}"
      end
      arbitration_rule
    end

    def edit_resource(type, id, data)
      attributes = build_rule_attributes(data)
      super(type, id, attributes)
    end

    def options
      render_options(:arbitration_rules, :field_values => ArbitrationRule.field_values)
    end

    private

    def build_rule_attributes(data)
      attributes = data.dup
      if data.key?('expression')
        attributes['expression'] = MiqExpression.new(data['expression'])
      end
      if data.key?('arbitration_profile')
        attributes['arbitration_profile_id'] = parse_id(attributes.delete('arbitration_profile'), :arbitration_profiles)
      end
      attributes
    end
  end
end
