module Job::StateMachine
  extend ActiveSupport::Concern

  module ClassMethods
    #
    # Helper methods for display of transitions
    #

    def to_dot(*args)
      new.to_dot(*args)
    end

    def to_svg(*args)
      new.to_svg(*args)
    end
  end

  def transitions
    @transitions ||= load_transitions
  end

  def state=(next_state)
    # '*' refers to any state; if next_state is '*', remain in current state.
    super unless next_state.nil? || next_state == '*'
  end

  # test whether the transition is allowed; if yes, transit to next state
  def transit_state(signal)
    permitted_transitions = transitions[signal.to_sym]
    unless permitted_transitions.nil?
      next_state = permitted_transitions[state]

      # if current state is not explicitly permitted, is any state (referred by '*') permitted?
      next_state = permitted_transitions['*'] unless next_state
      self.state = next_state
    end
    !!next_state
  end

  def signal_abort(*args)
    signal(:abort, *args)
  end

  def signal(signal, *args)
    signal = :abort_job if signal == :abort
    if transit_state(signal)
      save
      send(signal, *args) if respond_to?(signal)
    else
      raise _("%{signal} is not permitted at state %{state}") % {:signal => signal, :state => state}
    end
  end

  def queue_signal(*args, priority: MiqQueue::NORMAL_PRIORITY, role: nil, deliver_on: nil, server_guid: nil, queue_name: nil)
    MiqQueue.put(
      :class_name  => self.class.name,
      :method_name => "signal",
      :instance_id => id,
      :priority    => priority,
      :role        => role,
      :zone        => zone,
      :queue_name  => queue_name,
      :task_id     => guid,
      :args        => args,
      :deliver_on  => deliver_on,
      :server_guid => server_guid
    )
  end

  #
  # Helper methods for display of transitions
  #

  def to_dot(include_starred_states = false)
    all_states = transitions.values.map(&:to_a).flatten.uniq.reject { |t| t == "*" }

    "".tap do |s|
      s << "digraph #{self.class.name.inspect} {\n"
      transitions.each do |signal, signal_transitions|
        signal_transitions.each do |from, to|
          next if !include_starred_states && (from == "*" || to == "*")

          from = from == "*" ? all_states : [from]
          to   = to == "*"   ? all_states : [to]
          from.product(to).each { |f, t| s << "  #{f} -> #{t} [ label=\"#{signal}\" ]\n" }
        end
      end
      s << "}\n"
    end
  end

  def to_svg(include_starred_states = false)
    require "open3"
    out, err, _status = Open3.capture3("dot -Tsvg", :stdin_data => to_dot(include_starred_states))

    raise "Error from graphviz:\n#{err}" if err.present?

    out
  end
end
