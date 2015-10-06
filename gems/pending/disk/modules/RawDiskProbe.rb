module RawDiskProbe
  def self.probe(ostruct)
    return nil unless ostruct.fileName
    return("RawDisk") if ostruct.rawDisk
    (nil)
  end
end
