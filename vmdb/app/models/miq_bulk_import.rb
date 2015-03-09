require 'csv'

module MiqBulkImport
  def self.upload(fd, tags, keys)
    log_prefix = 'MIQ(MiqBulkImport.upload)'
    $log.info "#{log_prefix} Uploading CSV file"
    data = fd.read
    data.gsub!(/\r/, "\n")
    begin
      reader = CSV.parse(data)
    rescue CSV::IllegalFormatError
      $log.error "#{log_prefix} CSV file is invalid"
      raise "CSV file is invalid"
    end
    header = reader.shift

    tags = (header - keys).collect(&:dup) if tags.nil?

    verified_tags = tags.collect {|t| t if header.include?(t)}.compact
    unless verified_tags.empty?
      $log.info "#{log_prefix} The following columns are verified in the csv file: #{verified_tags.join(" and ")}"
    else
      raise "No valid columns were found in the csv file. One of the following fields is required: (#{tags.join(" ")})."
    end

    matched_keys = []
    keys.each {|k|
      if header.include?(k)
        matched_keys.push(k)
        tags = tags.unshift(k)
      end
    }

    if matched_keys.empty?
      $log.error "#{log_prefix} The following required columns used for matching are missing: #{keys.join(" or ")}"
      raise "The following required columns used for matching are missing: #{keys.join(" or ")}"
    end

    result = []
    reader.each {|row|
      next if row.first.nil?
      line = {}
      header.each_index{|i|
        next unless tags.include?(header[i])
        line[header[i]] = row[i].strip if row[i]
      }
      result.push(line)
    }
    return [result, matched_keys, verified_tags]
  end

  def self.find_entry_by_keys(klass, keys)
    keys2array = keys
    primary_key, primary_key_value = keys2array.shift
    result = klass.where("LOWER(#{primary_key}) LIKE '#{primary_key_value.downcase}'")
    return result if result.size <= 1

    filtered_result = []
    loop do
      break if keys2array.empty?

      sub_key, sub_key_value = keys2array.shift
      next if sub_key_value.blank?

      filtered_result = result.collect {|rec|
        rec if self.get_sub_key_values(rec, sub_key).include?(sub_key_value.downcase)
      }.compact

      return filtered_result if filtered_result.length == 1
    end

    return result # return original result if we were unable to resolve dups
  end

  def self.get_sub_key_values(rec, sub_key)
    if !sub_key.include?(".")
      return [] unless rec.respond_to?(sub_key)
      return rec.send(sub_key).downcase
    end

    # hardware.networks.hostname
    parts = sub_key.split(".")
    attr = parts.pop

    current = rec
    parts.each {|p|
      return [] if !current.is_a?(ActiveRecord::Base) && p != parts.last # we're only supporting multi-value for the last relationship
      return [] unless current.respond_to?(p)

      current = current.send(p)
    }
    current = current.is_a?(ActiveRecord::Base) ? [current] : current

    results = current.collect {|c|
      return [] unless c.respond_to?(attr)
      c.send(attr)
    }.compact

    return results
  end
end
