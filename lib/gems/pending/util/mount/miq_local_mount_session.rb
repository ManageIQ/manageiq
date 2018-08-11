require 'util/mount/miq_generic_mount_session'

# MiqLocalMountSession is meant to be a representation of the local file system
# that conforms to the same interface as MiqLocalMountSession (and by proxy,
# MiqFileSystem::Interface).
#
# See MiqGenericMountSession for info on methods available.
class MiqLocalMountSession < MiqGenericMountSession
  def self.uri_scheme
    "file".freeze
  end

  # no-op these since they are not relavent to the local file system
  #
  # rubocop:disable Style/SingleLineMethods, Layout/EmptyLineBetweenDefs
  def connect; end      # :nodoc:
  def disconnect; end   # :nodoc:
  def mount_share; end  # :nodoc:
  # rubocop:enable Style/SingleLineMethods, Layout/EmptyLineBetweenDefs

  def relative_to_mount(remote_file) # :nodoc:
    remote_file
  end

  def uri_to_local_path(remote_file) # :nodoc:
    File.expand_path(remote_file)
  end
end
