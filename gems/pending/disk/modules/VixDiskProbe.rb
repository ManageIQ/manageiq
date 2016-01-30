module VixDiskProbe
  def self.probe(ostruct)
    return("VixDiskMod") if ostruct.vixDiskInfo
    (nil)
  end
end
