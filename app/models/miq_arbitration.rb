class MiqArbitration
  # Will want to take in an MIQ Request
  # highest to lowest priority
  RULE_PRIORITIES = %w(Blueprint User).freeze

  def self.arbitrate_from_request(requester, blueprint)
    @requester = requester
    @blueprint = blueprint
    rules_init
    execute_rules
  end

  private_class_method :execute_rules, :blueprint_execute, :user_execute, :rules_init,
                       :inject, :disable_engine, :auto_reject, :require_approval, :auto_approve

  def self.execute_rules
    RULE_PRIORITIES.each do |rule_name|
      send("#{rule_name.downcase}_execute")
    end
  end

  def self.blueprint_execute
    User.with_user(@requester) do
      # ensure that the blueprint is able to be executed
      blueprints = Rbac.filtered('Blueprint')
      # TODO: Should not be a BadRequestError. Custom error?
      # TODO: Move into its own function?
      return BadRequestError unless blueprints.include?(@blueprint)
    end
    rules['Blueprint'].each do |rule|
      send(rule.operation) if rule.expression.evaluate(@blueprint)
    end
  end

  def self.user_execute
  end

  def self.rules_init
    @rules = {
      'Blueprint' => [],
      'User'      => []
    }
    ArbitrationRule.all.each { |rule| @rules[rule.expression.class_details].push(rule) }
  end

  class << self
    attr_reader :rules
  end

  def self.inject
  end

  def self.disable_engine
  end

  def self.auto_reject
  end

  def self.require_approval
  end

  def self.auto_approve
  end
end
