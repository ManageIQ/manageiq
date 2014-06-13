require 'NtUtil'

$:.push("#{File.dirname(__FILE__)}/../../../util")
require 'binary_struct'

module NTFS

	# 
  # STANDARD_INFORMATION - Attribute: Standard information (0x10).
  # 
  # NOTE: Always resident.
  # NOTE: Present in all base file records on a volume.
  # NOTE: There is conflicting information about the meaning of each of the time
  #   fields but the meaning as defined below has been verified to be
  #   correct by practical experimentation on Windows NT4 SP6a and is hence
  #   assumed to be the one and only correct interpretation.
  # 
		
	ATTRIB_STANDARD_INFORMATION = BinaryStruct.new([	  
		'Q',  'time_created',     # Time file was created. Updated when a filename is changed(?)
		'Q',  'time_altered',     # Time the data attribute was last modified
		'Q',  'time_mft_changed', # Time this mft record was last modified
		'Q',  'time_read',        # Approximate time when the file was last accessed (obviously 
		                          # this is not updated on read-only volumes). In Windows this 
		                          # is only updated when accessed if some time delta has passed 
		                          # since the last update. Also, last access times updates can be
		                          # disabled altogether for speed
		'L',  'dos_permissions',  # These are the flags we know as 'attributes' (see FP_ below)

    # 
    # If a volume has been upgraded from a previous NTFS version, then thes following
    # fields are present only if the file has been accessed since the upgrade.
    # Recognize the difference by comparing the length of the resident attribute
    # value. If it is 48, then the following fields are missing. If it is 72 then
    # the fields are present. Maybe just check like this:
    #  if (resident.ValueLength < sizeof(STANDARD_INFORMATION)) {
    #  	Assume NTFS 1.2- format.
    #  	If (volume version is 3.0+)
    #  		Upgrade attribute to NTFS 3.0 format.
    #  	else
    #  		Use NTFS 1.2- format for access.
    #  } else
    #  	Use NTFS 3.0 format for access.
    # Only problem is that it might be legal to set the length of the value to
    # arbitrarily large values thus spoiling this check. - But chkdsk probably
    # views that as a corruption, assuming that it behaves like this for all
    # attributes.
    # 
	  
		'L',  'max_versions',     # Maximum allowed versions for file. Zero if version numbering is disabled.
		'L',  'ver_num',          # This file's version (if any). Set to zero if maximum_versions is zero
		'L',  'class_id',         # Class id from bidirectional class id index (?)
		'L',  'owner_id',         # Owner_id of the user owning the file. Translate via $Q index 
		                          # in FILE_Extend /$Quota to the quota control entry for the user 
		                          # owning the file. Zero if quotas are disabled.
		'L',  'security_id',      # This is a key in the $SII index and the $SDS data stream in the file $Secure
		'Q',  'quota_charged',    # Number of bytes this file uses from the user's quota - total size of all streams - if zero then quotas are disabled
		'Q',  'update_seq_num',   # This is a direct index into the file $UsnJrnl - if zero then the USN journal is disabled
	])

	# One $STANDARD_INFORMATION attribute.
	class StandardInformation
		attr_reader :mTime, :aTime, :cTime, :permissions

		# 'DOS' File permissions.
		FP_READONLY   = 0x00000001
		FP_HIDDEN     = 0x00000002
		FP_SYSTEM     = 0x00000004
		FP_ARCHIVE    = 0x00000020
		FP_DEVICE     = 0x00000040
		FP_NORMAL     = 0x00000080
		FP_TEMPORARY  = 0x00000100
		FP_SPARSE     = 0x00000200
		FP_REPARSE    = 0x00000400
		FP_COMPRESSED = 0x00000800
		FP_OFFLINE    = 0x00001000
		FP_NOTINDEXED = 0x00002000
		FP_ENCRYPTED  = 0x00004000
		FP_DIRECTORY  = 0x10000000
		FP_INDEXVIEW  = 0x20000000
	  
		def initialize(buf)
			raise "MIQ(NTFS::StandardInformation.initialize) Nil buffer" if buf.nil?
			
			buf          = buf.read(buf.length) if buf.kind_of?(DataRun)
			@asi         = ATTRIB_STANDARD_INFORMATION.decode(buf)
			@mTime       = NtUtil.NtToRubyTime(@asi['time_altered'])
			@aTime       = NtUtil.NtToRubyTime(@asi['time_read'])
			@cTime       = NtUtil.NtToRubyTime(@asi['time_created'])
			@permissions = @asi['dos_permissions']
		end
	  
		def dump
			out = "\#<#{self.class}:0x#{'%08x' % self.object_id}>\n"
			out << "  Time created    : #{@cTime}\n"
			out << "  Time altered    : #{@mTime}\n"
			out << "  Time mft changed: #{NtUtil.NtToRubyTime(@asi['time_mft_changed'])}\n"
			out << "  Time read       : #{@aTime}\n"
			out << "  Permissions     : 0x#{'%08x' % @permissions}\n"
			out << "  Max versions    : #{@asi['max_versions']}\n"
			out << "  Version number  : #{@asi['ver_num']}\n"
			out << "  Class id        : #{@asi['class_id']}\n"
			out << "  Owner id        : #{@asi['owner_id']}\n"
			out << "  Security id     : #{@asi['security_id']}\n"
			out << "  Quota charged   : #{@asi['quota_charged']}\n"
			out << "  Update seq num  : #{@asi['update_seq_num']}\n"
			out << "---\n"
		end
	end
end # module NTFS
