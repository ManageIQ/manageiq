module ManageIQ::Providers
  class TagManager < BaseManager
    include SupportsFeatureMixin
    has_many :resources, :foreign_key => :ems_uid, :dependent => :destroy
  end
end
