module ApiHelper
  module Results
    def action_result(success, message = nil)
      res = { :success => success }
      res[:message] = message if message.present?
      res
    end

    def result_href(hash, type, id)
      hash[:href] = "#{@req[:base]}#{@req[:prefix]}/#{type}/#{id}"
      hash
    end

    def log_result(hash)
      hash.each { |k, v| api_log_info("Result: #{k}=#{v}") }
    end
  end
end
