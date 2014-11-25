require 'snmp'

class MiqSnmp

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
    $log.info "MIQ(SNMP-trap_v1) >> inputs=#{inputs.inspect}"

    host = inputs[:host] || inputs['host']
    port = inputs[:port] || inputs['port'] || 162

    # The enterprise OID from the IANA assigned numbers (www.iana.org/assignments/enterprise-numbers) as a String or an ObjectId.
    enterprise = inputs[:enterprise] || inputs['enterprise'] || self.enterprise_oid_string
    raise MiqException::Error,"MiqSnmp.trap_v1: Ensure that enterprise OID is provided" if enterprise.nil?

    # The IP address of the SNMP agent as a String or IpAddress.
    agent_address = inputs[:agent_address] || inputs['agent_address'] || self.agent_address
    raise MiqException::Error,"MiqSnmp.trap_v1: Ensure that server.host is configured properly in your vmdb.yml file" if agent_address.nil?

    # An integer respresenting the number of hundredths of a second that this system has been up.
    uptime = inputs[:sysuptime] || inputs['sysuptime'] || self.system_uptime

    # The generic trap identifier. One of :coldStart, :warmStart, :linkDown, :linkUp, :authenticationFailure, :egpNeighborLoss, or :enterpriseSpecific
    generic_trap = inputs[:generic_trap] || inputs['generic_trap']
    generic_trap = generic_trap.to_sym unless generic_trap.nil?
    generic_trap = :enterpriseSpecific unless [:coldStart, :warmStart, :linkDown, :linkUp, :authenticationFailure, :egpNeighborLoss, :enterpriseSpecific].include?(generic_trap)

    # An integer representing the specific trap type for an enterprise-specific trap.
    specific_trap = inputs[:specific_trap] || inputs['specific_trap']
    raise MiqException::Error,"MiqSnmp.trap_v1: Ensure that specific trap is provided" if specific_trap.nil? && generic_trap == :enterpriseSpecific

    # A list of additional varbinds to send with the trap.
    object_list = inputs[:object_list] || inputs['object_list'] || []
    vars = MiqSnmp.create_var_bind_list(object_list)

    hosts = host.kind_of?(Array) ? host : [host]
    hosts.each do |host|
      $log.info "MIQ(SNMP-trap_v1) Sending SNMP Trap (v1) to host=[#{host}], port=[#{port}], enterprise_id=[#{enterprise}], generic_trap=[#{generic_trap}], specific_trap=[#{specific_trap}], uptime=[#{uptime}], agent=[#{agent_address}], vars=#{vars.inspect}"
      SNMP::Manager.open(:Host => host, :TrapPort => port) do |manager|
        manager.trap_v1(enterprise, agent_address, generic_trap, specific_trap, uptime, vars)
      end
    end
  end

  def self.trap_v2(inputs)
    $log.info "MIQ(SNMP-trap_v2) >> inputs=#{inputs.inspect}"
    host = inputs[:host] || inputs['host']
    port = inputs[:port] || inputs['port'] || 162

    # An integer respresenting the number of hundredths of a second that this system has been up.
    uptime = inputs[:sysuptime] || inputs['sysuptime'] || self.system_uptime

    # trap_oid: An ObjectId or String with the OID identifier for this trap.
    trap_oid = inputs[:trap_oid] || inputs['trap_oid']
    raise MiqException::Error,"MiqSnmp.trap_v2: Ensure that a trap object id is provided" if trap_oid.nil?
    trap_oid = MiqSnmp.subst_oid(trap_oid)

    # A list of additional varbinds to send with the trap.
    object_list = inputs[:object_list] || inputs['object_list'] || []
    vars = MiqSnmp.create_var_bind_list(object_list, trap_oid)

    hosts = host.kind_of?(Array) ? host : [host]
    hosts.each do |host|
      $log.info "MIQ(SNMP-trap_v2) Sending SNMP Trap (v2) to host=[#{host}], port=[#{port}], trap_oid=[#{trap_oid}], vars=#{vars.inspect}"
      SNMP::Manager.open(:Host => host, :TrapPort => port) do |manager|
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

  private
  def self.create_var_bind_list(object_list, base = nil)
    vars = []
    object_list.each { |tuple|
      oid      = MiqSnmp.subst_oid(tuple[:oid], base)
      value    = tuple[:value]
      type     = tuple[:type] || tuple[:var_type]
      snmpType = AVAILABLE_TYPES_HASH[type]
      snmpVal  = (snmpType == SNMP::Null) ? SNMP::Null.new : snmpType.new(value)
      vars << SNMP::VarBind.new(oid, snmpVal)
    }
    vars
  end

  def self.subst_oid(oid, base = nil)
    oid = oid.strip

    # Set base to our enterprise oid, if uninitialize
    base = MiqSnmp.enterprise_oid_string if base.nil?

    # If it begins with a dot, append it to the base
    return "#{base}#{oid}" if oid[0,1] == "."

    # Need to move these to ManageIQ MIB
    oid = case oid.downcase
    when "info"                         then "#{MiqSnmp.enterprise_oid_string}.1"
    when "warn", "warning"              then "#{MiqSnmp.enterprise_oid_string}.2"
    when "crit", "critical", "error"    then "#{MiqSnmp.enterprise_oid_string}.3"
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

    return oid
  end

  def self.system_uptime
    (Time.now.utc - MiqServer.my_server.started_on.utc) * 100
  end

  def self.agent_address
    VMDB::Config.new("vmdb").get(:server, :host)
  end

end
