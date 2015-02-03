module ApiHelper
  module Results
    private

    def action_result(success, message = nil, options = {})
      res = {:success => success}
      res[:message] = message if message.present?
      add_task_to_result(res, options[:task_id]) if options[:task_id].present?
      res
    end

    def add_href_to_result(hash, type, id)
      hash[:href] = "#{@req[:base]}#{@req[:prefix]}/#{type}/#{id}"
      hash
    end

    def add_parent_href_to_result(hash)
      hash[:href] = "#{@req[:base]}#{@req[:prefix]}/#{@req[:collection]}/#{@req[:c_id]}"
      hash
    end

    def add_task_to_result(hash, task_id)
      hash[:task_id]   = task_id
      hash[:task_href] = "#{@req[:base]}#{@req[:prefix]}/tasks/#{task_id}"
      hash
    end

    def add_tag_to_result(hash, tag_spec)
      hash[:tag_category] = tag_spec[:category] if tag_spec[:category].present?
      hash[:tag_name]     = tag_spec[:name] if tag_spec[:name].present?
      hash[:tag_href]     = "#{@req[:base]}#{@req[:prefix]}/tags/#{tag_spec[:id]}" if tag_spec[:id].present?
      hash
    end

    def add_policy_to_result(hash, ctype, policy)
      return hash if policy.blank?
      hash["#{ctype.to_s.singularize}_id".to_sym]   = policy.id
      hash["#{ctype.to_s.singularize}_href".to_sym] = "#{@req[:base]}#{@req[:prefix]}/#{ctype}/#{policy.id}"
      hash
    end

    def log_result(hash)
      hash.each { |k, v| api_log_info("Result: #{k}=#{v}") }
    end
  end
end
