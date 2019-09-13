#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)

def getDinfo(vim)
  dinfo = []
  vim.virtualMachinesByMor.each do |_k, v|
    v['config']['hardware']['device'].each do |dev|
      next if dev.xsiType != "VirtualDisk"

      dinfo << {
        :fileName        => dev['backing']['fileName'],
        :capacityInKB    => dev['capacityInKB'].to_i,
        :diskMode        => dev['backing']['diskMode'],
        :thinProvisioned => dev['backing']['thinProvisioned']
      }
    end
  end
  dinfo
end

log_header = "MIQ(#{__FILE__})"
$log.info("#{log_header} Correcting Disk Sizes...")

disks_by_filename = Disk.all.inject({}) do |h, d|
  h[d.filename] = d
  h
end

changed_disks = {}

ExtManagementSystem.all.each do |e|
  $log.info("#{log_header} Correcting Disk Sizes for disks under ExtManagementSystem name: [#{e.name}], id: [#{e.id}]...")

  begin
    vim = e.connect
    dinfo = getDinfo(vim)
  rescue => err
    $log.error("#{log_header} Error during Correcting Disk Sizes for disks under ExtManagementSystem name: [#{e.name}], id: [#{e.id}]...Skipping")
    $log.log_backtrace(err)
    next
  ensure
    vim.disconnect if vim rescue nil
  end

  dinfo.each do |di|
    d = disks_by_filename[di[:fileName]]
    next if d.nil?

    data = {
      :new => {:size => di[:capacityInKB].kilobytes, :disk_type => (di[:thinProvisioned] == 'true') ? 'thin' : 'thick', :mode => di[:diskMode]},
      :old => {:size => d.size, :disk_type => d.disk_type, :mode => d.mode}
    }
    if data[:new] != data[:old]
      # Only nil out 'size_on_disk' if the provision size does not match
      data[:new][:size_on_disk] = nil if data[:new][:size] != data[:old][:size]
      changed_disks[d.id] = data
      d.update(data[:new])
    end
  end

  $log.info("#{log_header} Collecting Disk Sizes for disks under ExtManagementSystem name: [#{e.name}], id: [#{e.id}]...Complete")
end

$log.info("#{log_header} Changed disks: #{changed_disks.inspect}")
$log.info("#{log_header} Correcting Disk Sizes...Complete")
