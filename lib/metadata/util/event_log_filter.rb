module EventLogFilter
  def self.prepare_filter!(filter)
    raise ArgumentError, "filter must be a Hash" unless filter.kind_of?(Hash)

    filter[:rec_count] = 0 if filter[:rec_count].nil?

    filter[:num_days] = 0 if filter[:num_days].nil?
    filter[:generated] = (Time.now.utc - filter[:num_days] * 86400).iso8601 unless filter[:num_days] == 0

    filter[:level] = filter[:level].to_s.strip.downcase
    filter[:level] = filter[:level].empty? ? :warn : filter[:level].to_sym
    filter[:level] = :warn unless [:error, :warn, :info].include?(filter[:level])

    [:message, :source].each do |k|
      filter[k].strip! unless filter[k].nil?
      filter[k] = nil if filter[k] == ''
      unless filter[k].nil?
        first = filter[k][0, 1]
        last = filter[k][-1, 1]

        filter[k] = if first == '"' && last == '"'
          # Double quotes surrounding provide exact match
          Regexp.new("^\\s*#{Regexp.escape(filter[k][1..-2])}\\s*$", Regexp::IGNORECASE)
        elsif first == '/' && last == '/'
          # Forward slashes surrounding provide regex match
          Regexp.new(filter[k][1..-2], Regexp::IGNORECASE)
        else
          # Neither surrouding provides substring match
          Regexp.new(Regexp.escape(filter[k]), Regexp::IGNORECASE)
        end
      end
    end
    
    return filter
  end

  def self.filter_by_level?(level, filter)
    return case filter[:level]
    when :info then false
    when :warn then !['warn', 'error'].include?(level.to_s)
    when :error then 'error' != level.to_s
    else false
    end
  end

  def self.filter_by_generated?(generated, filter)
    filter[:generated] && generated < filter[:generated]
  end

  def self.filter_by_source?(source, filter)
    filter[:source] && source !~ filter[:source]
  end

  def self.filter_by_message?(message, filter)
    filter[:message] && message !~ filter[:message]
  end

  def self.filter_by_rec_count?(rec_count, filter)
    filter[:rec_count] > 0 && rec_count >= filter[:rec_count]
  end
end
