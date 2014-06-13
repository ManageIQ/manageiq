require "binary_struct"

# Parser for the Windows Image Format (WIM).
#   Information found here:
#     http://www.microsoft.com/en-us/download/details.aspx?id=13096
#     http://technet.microsoft.com/en-us/library/cc749478%28WS.10%29.aspx?ITPID=win7dtp
#     http://www.freepatentsonline.com/y2010/0211943.html
#     http://nunobrito1981.blogspot.com/2010/12/inaccuracy-on-wim-documentation.html
#
# TODO: Add support for processing winnt.h GUID structures for wim_guid.
#       http://msdn.microsoft.com/en-us/library/windows/desktop/aa373931%28v=vs.85%29.aspx
#       http://stackoverflow.com/questions/679381/accessing-guid-members-in-c-sharp
class WimParser
  autoload :NtUtil,   "#{File.dirname(__FILE__)}/../../fs/ntfs/NtUtil"
  autoload :Nokogiri, "nokogiri"

  HEADER_V1_STRUCT = BinaryStruct.new([
    'a8',  'image_tag',          # Signature that identifies the file as a .wim file. Value is set to “MSWIM\0\0”.
    'L',   'size',               # Size of the WIM header in bytes.
    'L',   'version',            # The current version of the .wim file. This number will increase if the format of the .wim file changes.
    'L',   'flags',              # Defines the custom flags (listed below).
    'L',   'compression_size',   # Size of the compressed .wim file in bytes.
    'a16', 'wim_guid',           # A unique identifier.
    'S',   'part_number',        # The part number of the current .wim file in a spanned set. This value is 1, unless the data of the .wim file was split into multiple parts (.swm).
    'S',   'total_parts',        # The total number of .wim file parts in a spanned set.
    'L',   'image_count',        # The number of images contained in the .wim file.
    'L',   'offset_table_size',  # The location of the resource lookup table.
    'L',   'offset_table_flags',
    'q',   'offset_table_offset',
    'q',   'offset_table_original_size',
    'L',   'xml_data_size',      # The location of the XML data.
    'L',   'xml_data_flags',
    'q',   'xml_data_offset',
    'q',   'xml_data_original_size',
    'L',   'boot_metadata_size', # The location of the metadata resource.
    'L',   'boot_metadata_flags',
    'q',   'boot_metadata_offset',
    'q',   'boot_metadata_original_size',
    'L',   'boot_index',         # The index of the bootable image in the .wim file. If this is zero, then there are no bootable images available.
    'L',   'integrity_size',     # The location of integrity table used to verify files.
    'L',   'integrity_flags',
    'q',   'integrity_offset',
    'q',   'integrity_original_size',
    'a60', 'unused'              # A reserved 60 bytes of additional space for future fields.
  ])
  SIZEOF_HEADER_V1_STRUCT = HEADER_V1_STRUCT.size

  IMAGE_TAG = "MSWIM\0\0\0"

  # Flags values for the header struct
  FLAG_HEADER_RESERVED          = 0x00000001
  FLAG_HEADER_COMPRESSION       = 0x00000002  # Resources within the WIM (both file and metadata) are compressed.
  FLAG_HEADER_READONLY          = 0x00000004  # The contents of this WIM should not be changed.
  FLAG_HEADER_SPANNED           = 0x00000008  # Resource data specified by the images within this WIM may be contained in another WIM.
  FLAG_HEADER_RESOURCE_ONLY     = 0x00000010  # This WIM contains file resources only.  It does not contain any file metadata.
  FLAG_HEADER_METADATA_ONLY     = 0x00000020  # This WIM contains file metadata only.
  FLAG_HEADER_WRITE_IN_PROGRESS = 0x00000040  # Limits one writer to the WIM file when opened with the WIM_FLAG_SHARE_WRITE mode, This flag is primarily used in the Windows Deployment Services (WDS) scenario.
  FLAG_HEADER_RP_FIX            = 0x00000080  # Reparse point fixup
  # Additionally, if the FLAG_HEADER_COMPRESSION flag is set, the following flags are valid:
  FLAG_HEADER_COMPRESS_RESERVED = 0x00010000
  FLAG_HEADER_COMPRESS_XPRESS   = 0x00020000  # Resources within the wim are compressed using XPRESS compression.
  FLAG_HEADER_COMPRESS_LZX      = 0x00040000  # Resources within the wim are compressed using LZX compression.

  attr_reader :filename

  def initialize(filename)
    @filename = filename
  end

  def header
    data = File.open(filename, "rb") do |f|
      f.read(SIZEOF_HEADER_V1_STRUCT)
    end
    ret = HEADER_V1_STRUCT.decode(data)
    raise "#{filename} is not a WIM file" if ret["image_tag"] != IMAGE_TAG
    ret
  end

  def xml_data
    header_data = header

    xml = File.open(filename, "rb") do |f|
      f.seek(header_data["xml_data_offset"])
      f.read(header_data["xml_data_size"])
    end
    xml.force_encoding("UTF-16")

    xml = Nokogiri::XML(xml).xpath("/WIM")

    ret = {}
    ret["total_bytes"] = xml.xpath("./TOTALBYTES").text.to_i
    ret["images"] = xml.xpath("./IMAGE").collect do |i|
      # Deal with hex time parts by removing the 0x prefix, padding with 0s to
      #   8 characters, appending the low part to the high part, converting
      #   to an integer, and then converting that to a time object.
      high_part     = i.xpath("./CREATIONTIME/HIGHPART").text[2..-1].rjust(8, '0')
      low_part      = i.xpath("./CREATIONTIME/LOWPART").text[2..-1].rjust(8, '0')
      creation_time = NtUtil.NtToRubyTime("#{high_part}#{low_part}".to_i(16))

      high_part     = i.xpath("./LASTMODIFICATIONTIME/HIGHPART").text[2..-1].rjust(8, '0')
      low_part      = i.xpath("./LASTMODIFICATIONTIME/LOWPART").text[2..-1].rjust(8, '0')
      last_mod_time = NtUtil.NtToRubyTime("#{high_part}#{low_part}".to_i(16))

      {
        "index"                  => i["INDEX"].to_i,
        "name"                   => i.xpath("./NAME").text,
        "description"            => i.xpath("./DESCRIPTION").text,
        "dir_count"              => i.xpath("./DIRCOUNT").text.to_i,
        "file_count"             => i.xpath("./FILECOUNT").text.to_i,
        "total_bytes"            => i.xpath("./TOTALBYTES").text.to_i,
        "hard_link_bytes"        => i.xpath("./HARDLINKBYTES").text.to_i,
        "creation_time"          => creation_time,
        "last_modification_time" => last_mod_time,
      }
    end
    ret
  end
end
