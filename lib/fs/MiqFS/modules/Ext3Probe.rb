$:.push("#{File.dirname(File.expand_path(__FILE__))}/../../ext3")
require 'Ext3Superblock'

module Ext3Probe

  def Ext3Probe.probe(dobj)
    $log.debug("Ext3Probe >> dobj=#{dobj}") if $log
    unless dobj.kind_of?(MiqDisk)
      $log.debug "Ext3Probe << FALSE because Disk Object class is not MiqDisk, but is '#{dobj.class.to_s}'" if $log
      return false
    end

    begin
      dobj.seek(0, IO::SEEK_SET)
      sb = Ext3::Superblock.new(dobj)

      # If initializing the superblock does not throw any errors, then this is ext3
      $log.debug("Ext3Probe << TRUE")
      return true
    rescue => err
      $log.debug "Ext3Probe << FALSE because #{err.message}" if $log
      return false
    ensure
      dobj.seek(0, IO::SEEK_SET)
    end
  end
end
