require 'csv'

module MiqBulkImport
  def self.upload(fd, tags, keys)
    _log.info("Uploading CSV file")
    data = fd.read
    raise _("File is empty") if data.empty?
    data.gsub!(/\r/, "\n")
    begin
      reader = CSV.parse(data)
    rescue CSV::IllegalFormatError
      _log.error("CSV file is invalid")
      raise "CSV file is invalid"
    end
    header = reader.shift

    tags = (header - keys).collect(&:dup) if tags.nil?

    verified_tags = tags.collect { |t| t if header.include?(t) }.compact
    if verified_tags.empty?
      raise "No valid columns were found in the csv file. One of the following fields is required: (#{tags.join(" ")})."
    else
      _log.info("The following columns are verified in the csv file: #{verified_tags.join(" and ")}")
    end

    matched_keys = []
    keys.each do |k|
      if header.include?(k)
        matched_keys.push(k)
        tags = tags.unshift(k)
      end
    end

    if matched_keys.empty?
      _log.error("The following required columns used for matching are missing: #{keys.join(" or ")}")
      raise "The following required columns used for matching are missing: #{keys.join(" or ")}"
    end

    result = []
    reader.each do |row|
      next if row.first.nil?
      line = {}
      header.each_index do |i|
        next unless tags.include?(header[i])
        line[header[i]] = row[i].strip if row[i]
      end
      result.push(line)
    end
    [result, matched_keys, verified_tags]
  end

  def self.find_entry_by_keys(klass, keys)
    keys2array = keys
    primary_key, primary_key_value = keys2array.shift
    result = klass.where(klass.arel_attribute(primary_key).lower.eq(primary_key_value.downcase))
    return result if result.size <= 1

    filtered_result = []
    loop do
      break if keys2array.empty?

      sub_key, sub_key_value = keys2array.shift
      next if sub_key_value.blank?

      filtered_result = result.collect do |rec|
        rec if get_sub_key_values(rec, sub_key).include?(sub_key_value.downcase)
      end.compact

      return filtered_result if filtered_result.length == 1
    end

    result # return original result if we were unable to resolve dups
  end

  def self.get_sub_key_values(rec, sub_key)
    unless sub_key.include?(".")
      return [] unless rec.respond_to?(sub_key)
      return rec.send(sub_key).downcase
    end

    # hardware.networks.hostname
    parts = sub_key.split(".")
    attr = parts.pop

    current = rec
    parts.each do |p|
      return [] if !current.kind_of?(ActiveRecord::Base) && p != parts.last # we're only supporting multi-value for the last relationship
      return [] unless current.respond_to?(p)

      current = current.send(p)
    end
    current = current.kind_of?(ActiveRecord::Base) ? [current] : current

    results = current.collect do |c|
      return [] unless c.respond_to?(attr)
      c.send(attr)
    end.compact

    results
  end
end
