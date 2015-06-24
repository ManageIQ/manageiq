module MiqAeEngine
  module MiqAeStateMachine
    def process_state(f, message, args)
      Benchmark.current_realtime[:state_count] += 1
      Benchmark.realtime_block(:state_time) do
        initialize_state_vars(f)
        # Do not proceed further unless this state is runnable
        return unless state_runnable?(f, 'main')
        run_state_steps(f, message, args)
      end
    end

    def run_state_steps(f, message, args)
      # Ensure the metadata to deal with retries and timeouts is initialized
      initialize_state_maxima_metadata

      # Process on_entry method
      on_entry(f)

      # Process the main state step
      main_step(f, message, args) unless @state_changed

      state_exit(f, message)
    end

    def state_runnable?(f, step)
      return true if %w(on_exit on_error).include?(step)
      return false unless (@workspace.root['ae_state'] == f['name'])
      return false unless (@workspace.root['ae_result'] == 'ok')
      true
    end

    def initialize_state_maxima_metadata
      @workspace.root['ae_state_started'] = Time.now.utc.to_s  if @workspace.root['ae_state_started'].blank?
      @workspace.root['ae_state_retries'] = 0                  if @workspace.root['ae_state_retries'].blank?
    end

    def reset_state_maxima_metadata
      @workspace.root['ae_state_started'] = ''
      @workspace.root['ae_state_retries'] = 0
    end

    def increment_state_retries
      @workspace.root['ae_state_retries'] = @workspace.root['ae_state_retries'].to_i + 1
    end

    def enforce_state_maxima(f)
      enforce_max_retries(f)
      enforce_max_time(f)
    end

    def enforce_max_time(f)
      return if f['max_time'].blank?
      now = Time.now.utc
      max_seconds = f['max_time'].to_i_with_method
      ae_state_started = Time.parse(@workspace.root['ae_state_started'])
      return if now - ae_state_started < max_seconds
      raise "time in state <#{now - ae_state_started} seconds> exceeded maximum of <#{max_seconds}>"
    end

    def enforce_max_retries(f)
      return if f['max_retries'].blank?
      return if @workspace.root['ae_state_retries'].to_i <= f['max_retries'].to_i

      raise "number of retries <#{@workspace.root['ae_state_retries']}> exceeded maximum of <#{f['max_retries']}>"
    end

    def initialize_step(step)
      @workspace.root['ae_state_step'] = step
      @workspace.root['ae_status_state'] = step # Legacy
      @current_state = @workspace.root['ae_state']
      @state_changed = false
    end

    def process_state_step_with_error_handling(f, step)
      return unless state_runnable?(f, step)
      begin
        initialize_step(step)
        yield
        check_state_change
      rescue => e
        error_message = "State=<#{f['name']}> running #{step} raised exception: <#{e.message}>"
        $miq_ae_logger.error error_message
        @workspace.root['ae_reason'] = error_message
        @workspace.root['ae_result'] = 'error'
      end
    end

    def check_state_change
      return if @workspace.root['ae_result'] == 'retry'
      reset_ae_state_changes
      next_state = @workspace.root['ae_next_state']
      @state_changed = @workspace.root['ae_state'] != next_state unless next_state.blank?
    end

    def reset_ae_state_changes
      return if @current_state == @workspace.root['ae_state']
      $miq_ae_logger.warn "Invalid state changed from #{@current_state} to #{@workspace.root['ae_state']}"
      @workspace.root['ae_next_state'] = @workspace.root['ae_state']
      @workspace.root['ae_state'] = @current_state
    end

    def initialize_state_vars(f)
      # Initialize the ae_state and ae_result variables, if blank
      @workspace.root['ae_state']  = f['name'] if @workspace.root['ae_state'].blank?
      @workspace.root['ae_result'] = 'ok'      if @workspace.root['ae_result'].blank?
    end

    def state_exit(f, message)
      # Check the ae_result and set the next state appropriately
      case @workspace.root['ae_result']
      when 'ok' then
        on_exit(f, message)
      when 'skip' then
        $miq_ae_logger.info "Skipping State=[#{@current_state}]"
        set_next_state(f, message)
        @workspace.root['ae_result'] = 'ok'
      when 'retry' then
        increment_state_retries
        on_exit(f, message)
      when 'error' then
        on_error(f, message)
      end
    end

    def on_entry(f)
      process_state_step_with_error_handling(f, 'on_entry') do
        process_state_methods(f, 'on_entry')
      end
    end

    def main_step(f, message, args)
      relationship = get_value(f, :aetype_relationship)
      return if relationship.blank? || relationship.lstrip[0, 1] == '#'
      process_state_step_with_error_handling(f, 'main') do
        $miq_ae_logger.info "Processing State=[#{f['name']}]"
        process_state_relationship(f, relationship, message, args)
      end
    end

    def on_exit(f, message)
      process_state_step_with_error_handling(f, 'on_exit') do
        process_state_methods(f, 'on_exit')
      end
      set_next_state(f, message) unless @workspace.root['ae_result'] == 'retry'
    end

    def on_error(f, message)
      $miq_ae_logger.warn "Error in State=[#{f['name']}]"
      # Process on_error method
      process_state_step_with_error_handling(f, 'on_error') do
        process_state_methods(f, 'on_error')
        if @workspace.root['ae_result'] == 'continue'
          $miq_ae_logger.info "Ignoring error in state=[#{@current_state}]"
          @workspace.root['ae_result'] = 'ok'
        end
      end
      set_next_state(f, message) if @workspace.root['ae_result'] == 'ok'
    end

    def set_next_state(f, message)
      @workspace.root['ae_state'] = next_state_name(f['name'], message).to_s
      reset_state_maxima_metadata
      $miq_ae_logger.info "Next State=[#{@workspace.root['ae_state']}]"
    end

    def next_state_name(current, message)
      states = fields(message).collect { |f| f['name'] if f['aetype'] == 'state' }.compact
      return validate_user_changed_state(states) unless @workspace.root['ae_next_state'].blank?
      index  = states.index(current)
      index.nil? ? nil : states[index + 1]
    end

    def validate_user_changed_state(states)
      next_state = @workspace.root['ae_next_state']
      if next_state && states.exclude?(next_state)
        $miq_ae_logger.error "Next State=#{next_state} is invalid aborting state machine"
        raise MiqAeException::AbortInstantiation, "Invalid state specified <#{next_state}>"
      end
      $miq_ae_logger.warn "Method changed State to=#{next_state}"
      @workspace.root['ae_next_state'] = nil
      next_state
    end

    def process_state_relationship(f, relationship, message, args)
      enforce_state_maxima(f)
      process_relationship_raw(relationship, message, args, f['name'], f['collect'])
      raise MiqAeException::MiqAeDatastoreError, "empty relationship" unless @rels[f['name']]
      $miq_ae_logger.info "Processed  State=[#{f['name']}] with Result=[#{@workspace.root['ae_result']}]"
    end

    def process_state_methods(f, step)
      return if f[step].blank?
      f[step].split(";").each { |method| process_single_method(f, step, method) }
      rescue MiqAeException::MethodNotFound => err
        raise MiqAeException::MethodNotFound, "In State=[#{f['name']}], #{step} #{err.message}"
    end

    def process_single_method(f, step, method)
      method = substitute_value(method.strip)
      return if method.blank? || method.lstrip[0, 1] == '#'
      $miq_ae_logger.info "In State=[#{f['name']}], invoking [#{step}] method=[#{method}]"
      process_method_raw(method)
    end
  end
end
