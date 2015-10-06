module RawDiskProbe
  def self.probe(ostruct)
    return nil unless ostruct.fileName
    return("RawDisk") if ostruct.rawDisk || File.extname(ostruct.fileName).downcase == ".img"
    (nil)
  end
end
