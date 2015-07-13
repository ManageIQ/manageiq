$:.push("#{File.dirname(__FILE__)}/../../util")
require 'binary_struct'

module Ext4

  # ////////////////////////////////////////////////////////////////////////////
  # // Data definitions.

  EX_ATTRIB_NAME = [
    'C',  'name_len',       # Length of name
    'C',  'type',           # Type of attribute, see AT_ below.
    'S',  'offset_to_val',  # Offset to value.
    'L',  'blk_loc',        # Block location of value (not used).
    'L',  'size_of_val',    # Size in bytes of value.
    'L',  'hash_of_val',    # Hash of value.
  ]
  # Here follows the value name in ASCII.

  class ExAttribName

    AT_USER           = 1 # User space attribute.
    AT_POSIX_ACL      = 2 # POSIX ACL.
    AT_POSIX_ACL_DEF  = 3 # POSIX ACL default (directories only).
    AT_TRUSTED        = 4 # Trusted space attribute.
    AT_LUSTRE         = 5 # Not currently used.
    AT_SECURITY       = 6 # Security space attribute.

  end
end
