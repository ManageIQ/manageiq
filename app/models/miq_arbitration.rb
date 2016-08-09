class MiqArbitration
  def self.arbitrate_from_request(requester, blueprint)
    @requester = requester
    @blueprint = validate_blueprint(blueprint)
    execute_rules
  end

  class << self
    attr_accessor :blueprint, :requester

    private

    # Hardcoding rule priorities for now until system of
    # setting up priorities is in place
    RULE_PRIORITIES = {
      'Blueprint' => 'blueprint',
      'User'      => 'requester'
    }.freeze

    def validate_blueprint(blueprint)
      User.with_user(@requester) do
        blueprints = Rbac.filtered('Blueprint')
        return BadRequestError unless blueprints.include?(blueprint)
      end
      blueprint
    end

    def execute_rules
      RULE_PRIORITIES.each do |rule_name, attribute|
        rules = ArbitrationRule.get_by_rule_class(rule_name)
        rules.each do |rule|
          send(rule.operation, rule) if rule.expression.evaluate(send(attribute))
        end
      end
    end

    def inject(_rule)
    end

    def disable_engine(_rule)
    end

    def auto_reject(_rule)
    end

    def require_approval(_rule)
    end

    def auto_approval(_rule)
    end
  end
end
