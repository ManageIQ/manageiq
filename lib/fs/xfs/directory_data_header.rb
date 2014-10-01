require 'directory'
require 'directory2_data_header'
require 'directory3_data_header'
require 'superblock'

module XFS
  DIRECTORY_DATA_FREE = BinaryStruct.new([
    'S>',  'offset',              # start of freespace
    'S>',  'length',              # length of freespace
  ])
  SIZEOF_DIRECTORY_DATA_FREE    = DIRECTORY_DATA_FREE.size

  class DirectoryDataHeader
    XFS_DIR2_DATA_FD_COUNT      = 3

    attr_reader :data_header, :header_end, :version_3

    def decode_directory_header(data, header)
      template     = header.template
      @data_header = template.decode(data)
      header.magic_numbers.each { |magic_number| return template.size if @data_header['magic'] == magic_number }
      raise "XFS::DirectoryDataHeader: Invalid Magic Number #{@data_header['magic']}"
    end

    def initialize(data, sb)
      @sb = sb
      if @sb.version_has_crc?
        version_header = Directory3DataHeader.new
      else
        version_header = Directory2DataHeader.new
      end
      @version_3 = version_header.version_3
      header_size = decode_directory_header(data, version_header)
      free_offset = header_size
      @data_free    = []
      @free_end     = 0
      (1..XFS_DIR2_DATA_FD_COUNT).each do | i |
        @free_end     = header_size + SIZEOF_DIRECTORY_DATA_FREE * i
        @data_free[i] = DIRECTORY_DATA_FREE.decode(data[free_offset..@free_end])
        free_offset   = @free_end
      end
      @header_end = @free_end
      @header_end += version_header.pad
    end
  end # class DirectoryDataHeader
end   # module XFS
