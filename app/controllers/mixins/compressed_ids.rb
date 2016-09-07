module CompressedIds
  CID_OR_ID_MATCHER = ArRegion::CID_OR_ID_MATCHER
  #
  # Methods to convert record id (id, fixnum, 12000000000056) to/from compressed id (cid, string, "12r56")
  #   for use in UI controls (i.e. tree node ids, pulldown list items, etc)
  #

  def to_cid(id)
    ApplicationRecord.compress_id(id)
  end

  def from_cid(cid)
    ApplicationRecord.uncompress_id(cid)
  end

  def cid?(cid)
    ApplicationRecord.compressed_id?(cid)
  end
end
