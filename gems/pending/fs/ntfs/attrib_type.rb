module NTFS
		
	# The _ATTRIB_TYPE enumeration.
	# Every entry in the MFT is made of a list of attributes. These are the attrib types.
	AT_STANDARD_INFORMATION  = 0x00000010 # Base data: MAC times, version, owner, security, quota, permissions
	AT_ATTRIBUTE_LIST        = 0x00000020 # Used for a list of attributes that spans one MFT file record
	AT_FILE_NAME             = 0x00000030 # MAC times, size, flags, (and of course) file name
	AT_VOLUME_VERSION        = 0x00000040 # No information
	AT_OBJECT_ID             = 0x00000040 # Object GUID, birth GUIDs & domain GUID
	AT_SECURITY_DESCRIPTOR   = 0x00000050 # User & Group SIDs, system and descr ACLs
	AT_VOLUME_NAME           = 0x00000060 # Vol name (label)
	AT_VOLUME_INFORMATION    = 0x00000070 # Major, minor & flags (chkdsk & others)
	AT_DATA                  = 0x00000080 # File data, aux stream data
	AT_INDEX_ROOT            = 0x00000090 # Root of an index - usually root of directory
	AT_INDEX_ALLOCATION      = 0x000000a0 # Larger index structures use index allocation for overflow
	AT_BITMAP                = 0x000000b0 # Cluster allocation bitmap
	AT_SYMBOLIC_LINK         = 0x000000c0 # Haven't seen it yet
	AT_REPARSE_POINT         = 0x000000c0 # Reparse data
	AT_EA_INFORMATION        = 0x000000d0 # Extended attribute information
	AT_EA                    = 0x000000e0 # Extended attribute data
	AT_PROPERTY_SET          = 0x000000f0 # Haven't seen it
	AT_LOGGED_UTILITY_STREAM = 0x00000100 # Encrypted File System data
	AT_END                   = 0xffffffff # End of attributes
  
	# OBSOLETE TYPES
	# AT_VOLUME_VERSION and AT_SYMBOLIC_LINK have been depreciated, but remain in the type constants for
	# backward compatibility. The name hash can't contain them since the type is used as a key.
  
	# NT names for the attributes.
	TypeName = {
		AT_STANDARD_INFORMATION   => '$STANDARD_INFORMATION',
		AT_ATTRIBUTE_LIST         => '$ATTRIBUTE_LIST',
		AT_FILE_NAME              => '$FILE_NAME',
		#AT_VOLUME_VERSION        => '$VOLUME_VERSION',        # This type is depreciated.
		AT_OBJECT_ID              => '$OBJECT_ID',
		AT_SECURITY_DESCRIPTOR    => '$SECURITY_DESCRIPTOR',
		AT_VOLUME_NAME            => '$VOLUME_NAME',
		AT_VOLUME_INFORMATION     => '$VOLUME_INFORMATION',
		AT_DATA                   => '$DATA',
		AT_INDEX_ROOT             => '$INDEX_ROOT',
		AT_INDEX_ALLOCATION       => '$INDEX_ALLOCATION',
		AT_BITMAP                 => '$BITMAP',
		#AT_SYMBOLIC_LINK         => '$SYMBOLIC_LINK',         # This type is depreciated.
		AT_REPARSE_POINT          => '$REPARSE_POINT',
		AT_EA_INFORMATION         => '$EA_INFORMATION',
		AT_EA                     => '$EA',
		AT_PROPERTY_SET           => '$PROPERTY_SET',
		AT_LOGGED_UTILITY_STREAM  => '$LOGGED_UTILITY_STREAM'
	}
end # module NTFS
