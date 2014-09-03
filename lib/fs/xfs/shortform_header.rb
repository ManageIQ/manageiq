module XFS
  #
  # Directory Entry when stored internal to an inode.
  # Small directories are packed as tightly as possible so as to fit into the
  # literal area of the inode.  These "shortform" directories consist of a
  # single header followed by zero or more dir entries.  Due to the different
  # inode number storage size and the variable length name field in the dir
  # entry all these structures are variable length, and the accessors in
  # this file should be used to iterate over them.
  #
  DIR_SHORTERFORM_HEADER = BinaryStruct.new([
    'C',  'entry_count',         # count of entries
    'S',  'i8byte_count',        # count of 8-byte inode #s
    'a4', 'parent_ino_4byte',    # parent dir inode # stored as 4 8-bit values
  ])
  SIZEOF_DIR_SHORTERFORM_HEADER = DIR_SHORTERFORM_HEADER.size

  DIR_SHORTFORM_HEADER = BinaryStruct.new([
    'C',  'entry_count',         # count of entries
    'S',  'i8byte_count',        # count of 8-byte inode #s
    'a8', 'parent_ino_8byte',    # parent dir inode # stored as 8 8-bit values
  ])
  SIZEOF_DIR_SHORTFORM_HEADER = DIR_SHORTFORM_HEADER.size

  class ShortFormHeader
    attr_reader :short_form_header, :entry_count, :parent_inode, :size, :small_inode

    def initialize(data)
      @short_form_header = DIR_SHORTERFORM_HEADER.decode(data)
      @entry_count       = @short_form_header['entry_count']
      i8byte_count       = @short_form_header['i8byte_count']
      @parent_inode      = @short_form_header['parent_ino_4byte']
      @size              = SIZEOF_DIR_SHORTERFORM_HEADER
      @small_inode       = true
      if @entry_count == 0
        @entry_count       = i8byte_count
        @short_form_header = DIR_SHORTFORM_HEADER.decode(data)
        @parent_inode      = @short_form_header['parent_ino_8byte']
        @size              = SIZEOF_DIR_SHORTFORM_HEADER
        @small_inode       = nil
      end
    end
  end # class ShortFormHeader
end   # module XFS
