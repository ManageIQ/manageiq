class MiqArbitration
  # Will want to take in an MIQ Request
  # highest to lowest priority
  RULE_PRIORITIES = %w(Blueprint User).freeze

  def self.arbitrate_from_request(requester, blueprint)
    @requester = requester
    @blueprint = validate_blueprint(blueprint)
    @rules = {
      'Blueprint' => [],
      'User'      => []
    }
    rules_init
    execute_rules
  end

  class << self
    attr_reader :rules

    private

    def validate_blueprint(blueprint)
      User.with_user(@requester) do
        blueprints = Rbac.filtered('Blueprint')
        return BadRequestError unless blueprints.include?(blueprint)
      end
      blueprint
    end

    def execute_rules
      RULE_PRIORITIES.each do |rule_name|
        send("#{rule_name.downcase}_execute")
      end
    end

    def blueprint_execute
      rules['Blueprint'].each do |rule|
        send(rule.operation, rule) if rule.expression.evaluate(@blueprint)
      end
    end

    def user_execute
      rules['User'].each do |rule|
        send(rule.operation, rule) if rule.expression.evaluate(@requester)
      end
    end

    def rules_init
      ArbitrationRule.all.each do |rule|
        expression = rule.expression.class_details
        rules[expression].push(rule) if RULE_PRIORITIES.include?(expression)
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
