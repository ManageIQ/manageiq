class Controller < GuestDevice
  has_many :disks, :foreign_key => :controller_id, :dependent => :nullify, :inverse_of => :controller
end
