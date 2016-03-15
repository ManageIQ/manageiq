class MiqScvmmParsePowershell
  def output_to_attribute(winrm_output)
    attribute, stderr = stdout_stderr(winrm_output)
    if stderr =~ /Exception/ || stderr =~ /At line:/
      raise "Error running PowerShell command.\n #{stderr}"
    end
    $log.debug "MiqScvmmParsePowershell: STDERR is \"#{stderr}\"" unless stderr.nil? || $log.nil?
    attribute.split("\r\n").last
  end

  #
  # This method handles one or more lines of exactly one attribute.
  #
  def parse_single_attribute_values(output)
    parse_attribute_values(output)
  end

  def parse_multiple_attribute_values(output)
    parse_attribute_values(output, true)
  end

  #
  # This method handles one or more lines of one or more attributes.
  #
  def parse_attribute_values(output, multiple = nil)
    stdout, stderr  = parse_powershell_value(output)
    lines           = stdout.split("\r\n")
    dashes          = nil
    attributes      = []
    attribute_names = []
    lines.each do |line|
      next if line.nil? || line == ""
      if line =~ /^-+/
        dashes = true
        next
      end
      if dashes.nil?
        attribute_names = line.split(" ")
        next
      end
      line_parts = multiple.nil? ? [line.rstrip] : line.split(" ")
      raise "Incorrect number of PowerShell Output Attributes Found" if line_parts.size != attribute_names.size
      i = 0
      line_hash = {}
      attribute_names.each do |attribute|
        line_hash[attribute] = line_parts[i]
        i += 1
      end
      attributes << line_hash
    end
    return attributes, stderr
  end

  def parse_single_powershell_value(output)
    stdout, stderr = parse_powershell_value(output)
    return stdout.split("\r\n").first, stderr
  end

  def parse_powershell_value(output)
    stdout, stderr = stdout_stderr(output)
    $log.debug "MiqScvmmParsePowershell: STDOUT is \"#{stdout}\"" unless stdout.nil? || $log.nil?
    $log.debug "MiqScvmmParsePowershell: STDERR is \"#{stderr}\"" unless stderr.nil? || $log.nil?
    return stdout, stderr
  end

  private

  def stdout_stderr(output)
    stdout = ""
    stderr = ""
    output[:data].each do |d|
      stdout << d[:stdout] unless d[:stdout].nil?
      stderr << d[:stderr] unless d[:stderr].nil?
    end
    return stdout, stderr
  end
end
