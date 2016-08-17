module ManageIQ
  module API
    class BaseController
      module ArbitrationRules
        def create_resource_arbitration_rules(type, _id, data)
          attributes = build_rule_attributes(data)
          arbitration_rule = collection_class(type).create(attributes)
          if arbitration_rule.invalid?
            raise BadRequestError,
                  "Failed to create a new virtual template - #{arbitration_rule.errors.full_messages.join(', ')}"
          end
          arbitration_rule
        end

        def edit_resource_arbitration_rules(type, id, data)
          attributes = build_rule_attributes(data)
          edit_resource(type, id, attributes)
        end

        private

        def build_rule_attributes(data)
          return data unless data.key?('expression')
          attributes = data.dup
          attributes['expression'] = MiqExpression.new(data['expression'])
          attributes
        end
      end
    end
  end
end
