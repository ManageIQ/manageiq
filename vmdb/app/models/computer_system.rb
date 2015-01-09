class ComputerSystem < ActiveRecord::Base
  belongs_to :configured_system

  has_one :operating_system, :dependent => :destroy
  has_one :hardware, :dependent => :destroy
end
