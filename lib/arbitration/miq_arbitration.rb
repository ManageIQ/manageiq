class MiqArbitration
  def self.arbitrate_from_request(requester, blueprint)
    @requester = requester
    @blueprint = blueprint
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

    def execute_rules
      RULE_PRIORITIES.each do |rule_class, attribute|
        rules = ArbitrationRule.get_by_rule_class(rule_class)
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
