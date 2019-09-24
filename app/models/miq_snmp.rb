require 'snmp'

class MiqSnmp
  include Vmdb::Logging

  AVAILABLE_TYPES_HASH = {
    "Null"        => SNMP::Null,
    "Integer"     => SNMP::Integer,
    "Unsigned32"  => SNMP::Unsigned32,
    "OctetString" => SNMP::OctetString,
    "ObjectId"    => SNMP::ObjectId,
    "ObjectName"  => SNMP::ObjectName,
    "IpAddress"   => SNMP::IpAddress,
    "Counter32"   => SNMP::Counter32,
    "Counter64"   => SNMP::Counter64,
    "Gauge32"     => SNMP::Gauge32,
    "TimeTicks"   => SNMP::TimeTicks
  }

  def self.trap_v1(inputs)
    _log.info(">> inputs=#{inputs.inspect}")

    host = inputs[:host] || inputs['host']
    port = inputs[:port] || inputs['port'] || 162

    # The enterprise OID from the IANA assigned numbers (www.iana.org/assignments/enterprise-numbers) as a String or an ObjectId.
    enterprise = inputs[:enterprise] || inputs['enterprise'] || enterprise_oid_string
    raise MiqException::Error, _("MiqSnmp.trap_v1: Ensure that enterprise OID is provided") if enterprise.nil?

    # The IP address of the SNMP agent as a String or IpAddress.
    address = inputs[:agent_address] || inputs['agent_address'] || agent_address
    if address.nil?
      raise MiqException::Error,
            _("MiqSnmp.trap_v1: Ensure that server.host is configured properly in your settings.yml file")
    end

    # An integer respresenting the number of hundredths of a second that this system has been up.
    uptime = inputs[:sysuptime] || inputs['sysuptime'] || system_uptime

    # The generic trap identifier. One of :coldStart, :warmStart, :linkDown, :linkUp, :authenticationFailure, :egpNeighborLoss, or :enterpriseSpecific
    generic_trap = inputs[:generic_trap] || inputs['generic_trap']
    generic_trap = generic_trap.to_sym unless generic_trap.nil?
    generic_trap = :enterpriseSpecific unless [:coldStart, :warmStart, :linkDown, :linkUp, :authenticationFailure, :egpNeighborLoss, :enterpriseSpecific].include?(generic_trap)

    # An integer representing the specific trap type for an enterprise-specific trap.
    specific_trap = inputs[:specific_trap] || inputs['specific_trap']
    if specific_trap.nil? && generic_trap == :enterpriseSpecific
      raise MiqException::Error, _("MiqSnmp.trap_v1: Ensure that specific trap is provided")
    end

    # A list of additional varbinds to send with the trap.
    object_list = inputs[:object_list] || inputs['object_list'] || []
    vars = create_var_bind_list(object_list)

    hosts = host.kind_of?(Array) ? host : [host]
    hosts.each do |lhost|
      _log.info("Sending SNMP Trap (v1) to host=[#{lhost}], port=[#{port}], enterprise_id=[#{enterprise}], generic_trap=[#{generic_trap}], specific_trap=[#{specific_trap}], uptime=[#{uptime}], agent=[#{agent_address}], vars=#{vars.inspect}")
      SNMP::Manager.open(:Host => lhost, :TrapPort => port) do |manager|
        manager.trap_v1(enterprise, agent_address, generic_trap, specific_trap, uptime, vars)
      end
    end
  end

  def self.trap_v2(inputs)
    _log.info(">> inputs=#{inputs.inspect}")
    host = inputs[:host] || inputs['host']
    port = inputs[:port] || inputs['port'] || 162

    # An integer respresenting the number of hundredths of a second that this system has been up.
    uptime = inputs[:sysuptime] || inputs['sysuptime'] || system_uptime

    # trap_oid: An ObjectId or String with the OID identifier for this trap.
    trap_oid = inputs[:trap_oid] || inputs['trap_oid']
    raise MiqException::Error, _("MiqSnmp.trap_v2: Ensure that a trap object id is provided") if trap_oid.nil?
    trap_oid = subst_oid(trap_oid)

    # A list of additional varbinds to send with the trap.
    object_list = inputs[:object_list] || inputs['object_list'] || []
    vars = create_var_bind_list(object_list, trap_oid)

    hosts = host.kind_of?(Array) ? host : [host]
    hosts.each do |lhost|
      _log.info("Sending SNMP Trap (v2) to host=[#{lhost}], port=[#{port}], trap_oid=[#{trap_oid}], vars=#{vars.inspect}")
      SNMP::Manager.open(:Host => lhost, :TrapPort => port) do |manager|
        manager.trap_v2(uptime, trap_oid, vars)
      end
    end
  end

  # IANA assigned Private Enterprise Number 33482 to ManageIQ
  def self.enterprise_oid_string
    @@enterprise_oid_string ||= "1.3.6.1.4.1.33482"
  end

  def self.enterprise_oid
    @@enterprise_oid ||= SNMP::ObjectId.new(enterprise_oid_string)
  end

  def self.available_types
    AVAILABLE_TYPES_HASH.keys
  end

  def self.create_var_bind_list(object_list, base = nil)
    vars = []
    object_list.each do |tuple|
      oid      = subst_oid(tuple[:oid], base)
      value    = tuple[:value]
      type     = tuple[:type] || tuple[:var_type]
      snmpType = AVAILABLE_TYPES_HASH[type]
      snmpVal  = (snmpType == SNMP::Null) ? SNMP::Null.new : snmpType.new(value)
      vars << SNMP::VarBind.new(oid, snmpVal)
    end
    vars
  end
  private_class_method :create_var_bind_list

  def self.subst_oid(oid, base = nil)
    oid = oid.strip

    # Set base to our enterprise oid, if uninitialize
    base = enterprise_oid_string if base.nil?

    # If it begins with a dot, append it to the base
    return "#{base}#{oid}" if oid[0, 1] == "."

    # Need to move these to ManageIQ MIB
    oid = case oid.downcase
          when "info"                         then "#{enterprise_oid_string}.1"
          when "warn", "warning"              then "#{enterprise_oid_string}.2"
          when "crit", "critical", "error"    then "#{enterprise_oid_string}.3"
          when "description"                  then "#{base}.1"
          when "category"                     then "#{base}.2"
          when "message"                      then "#{base}.3"
          when "object"                       then "#{base}.4"
          when "location"                     then "#{base}.5"
          when "platform"                     then "#{base}.6"
          when "url"                          then "#{base}.7"
          when "source"                       then "#{base}.8"
          when "custom1"                      then "#{base}.9"
          when "custom2"                      then "#{base}.10"
          else                                     oid
          end

    oid
  end
  private_class_method :subst_oid

  def self.system_uptime
    (Time.now.utc - MiqServer.my_server.started_on.utc) * 100
  end
  private_class_method :system_uptime

  def self.agent_address
    Settings.server.host
  end
  private_class_method :agent_address
end
