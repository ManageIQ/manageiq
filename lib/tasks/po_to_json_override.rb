class PoToJson
  #
  # PoToJson's json generation method is current not public, and the generate_for_jed
  #   method has extra stuff around it.  This override only returns the JSON.
  #
  # Overrides https://github.com/webhippie/po_to_json/blob/v1.0.1/lib/po_to_json.rb#L46-L65
  def generate_for_jed(language, overwrite = {})
    @options = parse_options(overwrite.merge(:language => language))
    @parsed ||= inject_meta(parse_document)

    build_json_for(build_jed_for(@parsed))
  end

  #
  # The following two methods override the base methods to account for proper
  # escaping of escape strings.
  #

  # Overrides https://github.com/webhippie/po_to_json/blob/v1.0.1/lib/po_to_json.rb#L90-L99
  def parse_header
    return if reject_header

    values[""][0].split("\n").each do |line|
      next if line.empty?

      build_header_for(line)
    end

    values[""] = headers
  end

  protected

  # Overrides https://github.com/webhippie/po_to_json/blob/v1.0.1/lib/po_to_json.rb#L175-L188
  def push_buffer(value, key = nil)
    value = JSON.load(value)

    if key.nil?
      buffer[lastkey] = [
        buffer[lastkey],
        value
      ].join("")
    else
      buffer[key] = value
      @lastkey = key
    end
  end
end
