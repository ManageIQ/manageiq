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

    def add_task_to_result(hash, task_id)
      hash[:task_id]   = task_id
      hash[:task_href] = "#{@req[:base]}#{@req[:prefix]}/tasks/#{task_id}"
      hash
    end

    def log_result(hash)
      hash.each { |k, v| api_log_info("Result: #{k}=#{v}") }
    end
  end
end
