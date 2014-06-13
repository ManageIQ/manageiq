$:.push("#{File.dirname(__FILE__)}/../../util")
require 'binary_struct'

module Ext4

  # ////////////////////////////////////////////////////////////////////////////
  # // Data definitions.

  POSIX_ACL_HEADER = [
    'L',  'version',  # Always 1, or 1 is all that's supported.
  ]

  class PosixAclHeader
  end
end
