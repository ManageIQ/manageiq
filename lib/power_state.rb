class PowerState
  attr_reader :service, :states

  ACTION_MAP = {
    :starting   => :start,
    :stopping   => :stop,
    :suspending => :suspending
  }.freeze

  def self.current(options, service)
    ps = new(options, service)
    ps.current
  end

  def initialize(options, service)
    @service = service
    @states = service.power_states
    @options = options
  end

  def current
    determine_power_state
  end

  def partialize
    "partial_#{partial_state_calculation}"
  end

  private

  def determine_power_state
    Service::POWER_STATE_MAP.each do |action, value|
      return value if @service.power_states_match?(action, @states)
    end
    partialize
  end

  def partial_state_calculation
    summed_hash = @states.each_with_object(Hash.new { |h, k| h[k] = 0 }) do |e, total|
      total[e] += 1
    end
    greatest_value = summed_hash.values.sort.last
    summed_hash.select { |x| summed_hash[x] == greatest_value }.keys.first
  end
end
