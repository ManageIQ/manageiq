HostVmware.all.each do |host|
  if host.ipaddress.blank?
    STDERR.puts "Host ID=#{host.id.inspect}, Name=#{host.name.inspect} has no IP Address"
    next
  end

  if host.guid.blank?
    STDERR.puts "Host ID=#{host.id.inspect}, Name=#{host.name.inspect} has no GUID"
    next
  end

  if host.ipaddress.ipaddress?
    ipaddress = host.ipaddress
  else
    begin
      ipaddress = MiqSockUtil.resolve_hostname(host.ipaddress)
    rescue SocketError => err
      STDERR.puts "Cannot resolve hostname(#{host.ipaddress}) for Host ID=#{host.id.inspect}, Name=#{host.name.inspect} because #{err.message}"
      next
    end
  end

  STDOUT.puts "#{ipaddress}\t#{host.guid}"
end
