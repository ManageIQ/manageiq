class ProviderOpenstack < Provider
  has_one :infra_ems,
          :foreign_key => "provider_id",
          :class_name  => "EmsOpenstackInfra",
          :dependent   => :destroy,
          :autosave    => true
  has_many :cloud_ems,
           :foreign_key => "provider_id",
           :class_name  => "EmsOpenstack",
           :dependent   => :destroy,
           :autosave    => true

  validates :name, :presence => true, :uniqueness => true
end
