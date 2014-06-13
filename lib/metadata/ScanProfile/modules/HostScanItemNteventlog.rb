$:.push("#{File.dirname(__FILE__)}/../../../metadata/util")
require 'event_log_filter'

require 'digest/md5'

module HostScanItemNteventlog
  def parse_data(vim, data, &blk)
    d = self.scan_definition
    filter = d["content"][0][:filter]
    if filter.nil?
      $log.warn("MIQ(#{self.class.name}.parse_data) Unable to find hostd filter in scan profile [host default]")
      return
    end
    
    data = vim.browseDiagnosticLogEx('hostd') if data.nil?
    d[:data] = hostd_log_to_hashes(data, filter)
  end

  #
  # Diagnostic Log Parsing
  #

  def hostd_log_to_hashes(log, filter = nil)
    filter ||= {}
    EventLogFilter.prepare_filter!(filter)

    ret = []
    rec_count = 0

    log['lineText'].each do |line|
      next unless line[0, 1] == '['
      next unless i = line.index(']')
      header, message = line[1..i - 1], line[i + 1..-1]

      # Process the header parts
      parts = header.split(' ')
      next unless parts.length >= 5

      # Different versions of ESX hosts order the log messages differently
      #   old: date, time, quoted source, hash, level
      #   new: date, time, hash, level, quoted source
      # Check that the last character of the last part is a quote to determine
      #   the versions
      if parts[-1][-1, 1] != "'"
        level = -1
        source_start = 2
        source_end = -3
      else
        level = 3
        source_start = 4
        source_end = -1
      end

      level = parts[level]
      level = "warn" if level == "warning"
      next if EventLogFilter.filter_by_level?(level, filter)

      source = parts[source_start..source_end].join(' ')
      source = source[1..-2] # Remove the surrounding quotes
      next if EventLogFilter.filter_by_source?(source, filter)

      generated = Time.parse(parts[0..1].join(' ')).utc.iso8601
      next if EventLogFilter.filter_by_generated?(generated, filter)

      message.strip!
      next if EventLogFilter.filter_by_message?(message, filter)

      name = 'hostd'

      ret << {
        :generated => generated,
        :name => name,
        :level => level,
        :source => source,
        :message => message,
        :uid => Digest::MD5.hexdigest("#{generated} #{name} #{level} #{source} #{message}")
      }

      rec_count += 1
      break if EventLogFilter.filter_by_rec_count?(rec_count, filter)
    end

    return ret
  end
end
