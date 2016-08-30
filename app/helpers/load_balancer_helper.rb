module LoadBalancerHelper
  include_concern 'TextualSummary'

  # Display a protocol and port_range as a string suitable for rendering (e.g.
  #   "TCP:1000-1010").
  #
  # @param protocol [#to_s] the protocol to render
  # @param port_range [Range, nil] a range of ports (or nil, in which case "nil"
  #   is rendered)
  # @return [String] the resulting string
  def self.display_protocol_port_range(protocol, port_range)
    "#{protocol}:#{display_port_range(port_range)}"
  end

  # Convert a Range object into the string representation usually seen for port
  # ranges (specifically, "80" or "3200-3233")
  #
  # @param r [Range, nil] a range of ports (or nil, in which case "nil" is
  #   rendered)
  # @return [String] the resulting string
  def self.display_port_range(r)
    if r.nil?
      "nil"
    elsif r.size == 0 # rubocop:disable Style/ZeroLengthPredicate
      ""
    elsif r.size == 1
      r.first.to_s
    else
      "#{r.min}-#{r.max}"
    end
  end
end
