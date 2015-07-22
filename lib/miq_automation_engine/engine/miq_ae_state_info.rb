module MiqAeEngine
  module MiqAeStateInfo
    STATE_SALIENT_ATTRIBUTES = %w(ae_state ae_state_retries ae_state_started)

    def save_current_state_info(key)
      return unless root && root['ae_state']
      root_state_hash  = {}
      STATE_SALIENT_ATTRIBUTES.each { |k| root_state_hash[k] = root[k] }
      @current_state_info[key] = root_state_hash
    end

    def reset_state_info(key)
      return unless root
      STATE_SALIENT_ATTRIBUTES.each { |k| root[k] = nil }
      return unless @current_state_info.key?(key)
      @current_state_info[key].each { |k, v| root[k] = v }
    end

    def load_previous_state_info(yaml)
      @current_state_info = YAML.load(yaml)
    end
  end
end
