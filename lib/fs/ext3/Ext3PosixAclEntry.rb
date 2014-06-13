$:.push("#{File.dirname(__FILE__)}/../../util")
require 'binary_struct'

module Ext3
		
	# ////////////////////////////////////////////////////////////////////////////
	# // Data definitions.

	POSIX_ACL_ENTRY = [
		'S',	'type',					# Entry type, see ET_ below.
		'S',	'permissions',	# Permissions, see EP_ below.
		'L',	'u_g_id',				# User / Group id (not defined for some types).
	]

	class PosixAclEntry
		
		module EntryType
			ET_U_INODE			= 0x01	# User, specified in inode.
			ET_U_ATTRIB			= 0x02	# User, specified in attribute.
			ET_G_INODE			= 0x04	# Group, specified in inode.
			ET_G_ATTRUB			= 0x08	# Group, specified in attribute.
			ET_RIGHTS_MASK	= 0x10	# Effective rights mask.
			ET_O						= 0x20	# Other, all other users.
		end
		include EntryType
		
		module EntryPermissions
			EP_EXECUTE	= 0x01	# Execute permission.
			EP_WRITE		= 0x02	# Write permission.
			EP_READ			= 0x04	# Read permission.
		end
		include EntryPermissions
		
	end
end
