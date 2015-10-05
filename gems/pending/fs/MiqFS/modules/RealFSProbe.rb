module RealFSProbe
  def self.probe(dobj)
    return(true) if dobj.to_s == "test_disk"
    (false)
  end
end
