module LocalDevProbe
  def self.probe(ostruct)
    return("LocalDevMod") if ostruct.localDev || File.blockdev?(ostruct.fileName)
    (nil)
  end
end
