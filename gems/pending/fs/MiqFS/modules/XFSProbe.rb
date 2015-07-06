$LOAD_PATH.push("#{File.dirname(File.expand_path(__FILE__))}/../../xfs")
require 'superblock'

module XFSProbe
  def self.probe(dobj)
    $log.debug("XFSProbe >> dobj=#{dobj}") if $log
    unless dobj.kind_of?(MiqDisk)
      $log.debug "XFSProbe << FALSE because Disk Object class is not MiqDisk, but is '#{dobj.class}'" if $log
      return false
    end

    begin
      # The first Allocation Group's Superblock is at block zero.
      dobj.seek(0, IO::SEEK_SET)
      XFS::Superblock.new(dobj)

      # If initializing the superblock does not throw any errors, then this is XFS
      $log.debug("XFSProbe << TRUE")
      return true
    rescue => err
      $log.debug "XFSProbe << FALSE because #{err.message}" if $log
      return false
    ensure
      dobj.seek(0, IO::SEEK_SET)
    end
  end
end
