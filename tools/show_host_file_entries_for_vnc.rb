#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)

ManageIQ::Providers::Vmware::Host.all.each do |host|
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
    require 'socket'
    begin
      ipaddress = TCPSocket.gethostbyname(host.ipaddress.split(',').first).last
    rescue SocketError => err
      STDERR.puts "Cannot resolve hostname(#{host.ipaddress}) for Host ID=#{host.id.inspect}, Name=#{host.name.inspect} because #{err.message}"
      next
    end
  end

  STDOUT.puts "#{ipaddress}\t#{host.guid}"
end
