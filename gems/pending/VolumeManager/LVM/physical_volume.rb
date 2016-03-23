#
# One object of this class for each physical volume in a volume group.
#
class PhysicalVolume
  attr_accessor :pvId, :pvName, :device, :deviceSize, :peStart, :peCount, :status, :vgObj, :diskObj

  def initialize(pvId = nil, pvName = nil, device = nil, deviceSize = nil, peStart = nil, peCount = nil)
    @pvId = pvId                        # the UUID of this physical volume
    @pvName = pvName                    # the name of this physical volume
    @device = device                    # the physical volume's device node under /dev.
    @deviceSize = deviceSize            # the size if this physical volume (in )
    @peStart = peStart.to_i             # the sector number of the first physical extent on this PV
    @peCount = peCount.to_i             # the number of physical extents on this PV

    @status = []
    @vgObj = nil                        # a reference to this PV's volume group
    @diskObj = nil                      # a reference to the MiqDisk object for this PV
  end
end # class PhysicalVolume
