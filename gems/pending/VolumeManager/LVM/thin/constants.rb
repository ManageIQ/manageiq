module Lvm2Thin
  SECTOR_SIZE = 512

  THIN_MAGIC = 27022010

  SPACE_MAP_ROOT_SIZE = 128

  MAX_METADATA_BITMAPS = 255

  SUPERBLOCK = BinaryStruct.new([
   'L',                       'csum',
   'L',                       'flags_',
   'Q',                       'block',
   'A16',                     'uuid',
   'Q',                       'magic',
   'L',                       'version',
   'L',                       'time',

   'Q',                       'trans_id',
   'Q',                       'metadata_snap',

   "A#{SPACE_MAP_ROOT_SIZE}", 'data_space_map_root',
   "A#{SPACE_MAP_ROOT_SIZE}", 'metadata_space_map_root',

   'Q',                       'data_mapping_root',

   'Q',                       'device_details_root',

   'L',                       'data_block_size',     # in 512-byte sectors

   'L',                       'metadata_block_size', # in 512-byte sectors
   'Q',                       'metadata_nr_blocks',

   'L',                       'compat_flags',
   'L',                       'compat_ro_flags',
   'L',                       'incompat_flags'
  ])

  SPACE_MAP = BinaryStruct.new([
    'Q',                      'nr_blocks',
    'Q',                      'nr_allocated',
    'Q',                      'bitmap_root',
    'Q',                      'ref_count_root'
  ])

  DISK_NODE = BinaryStruct.new([
    'L',                      'csum',
    'L',                      'flags',
    'Q',                      'blocknr',

    'L',                      'nr_entries',
    'L',                      'max_entries',
    'L',                      'value_size',
    'L',                      'padding'
    #'Q',                      'keys'
  ])

  INDEX_ENTRY = BinaryStruct.new([
    'Q',                      'blocknr',
    'L',                      'nr_free',
    'L',                      'none_free_before'
  ])

  METADATA_INDEX = BinaryStruct.new([
    'L',                      'csum',
    'L',                      'padding',
    'Q',                      'blocknr'
  ])

  BITMAP_HEADER = BinaryStruct.new([
    'L',                      'csum',
    'L',                      'notused',
    'Q',                      'blocknr'
  ])

  DEVICE_DETAILS = BinaryStruct.new([
    'Q',                      'mapped_blocks',
    'Q',                      'transaction_id',
    'L',                      'creation_time',
    'L',                      'snapshotted_time'
  ])

  MAPPING_DETAILS = BinaryStruct.new([
    'Q',                       'value'
  ])
end # module Lvm2Thin
