class Job
  module StateMachine
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

    def signal(signal, *args)
      signal = :abort_job if signal == :abort
      if transit_state(signal)
        save
        send(signal, *args) if respond_to?(signal)
      else
        raise "#{signal} is not permitted at state #{state}"
      end
    end
  end
end
