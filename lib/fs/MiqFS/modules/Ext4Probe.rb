$:.push("#{File.dirname(File.expand_path(__FILE__))}/../../ext4")
require 'Ext4Superblock'

module Ext4Probe

  def Ext4Probe.probe(dobj)
    $log.debug("Ext4Probe >> dobj=#{dobj}") if $log
    unless dobj.kind_of?(MiqDisk)
      $log.debug "Ext4Probe << FALSE because Disk Object class is not MiqDisk, but is '#{dobj.class.to_s}'" if $log
      return false
    end

    begin
      dobj.seek(0, IO::SEEK_SET)
      sb = Ext4::Superblock.new(dobj)

      # If initializing the superblock does not throw any errors, then this is Ext4
      $log.debug("Ext4Probe << TRUE")
      return true
    rescue => err
      $log.debug "Ext4Probe << FALSE because #{err.message}" if $log
      return false
    ensure
      dobj.seek(0, IO::SEEK_SET)
    end
  end
end
