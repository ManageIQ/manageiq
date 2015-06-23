class ProviderOpenstack < Provider
  has_one :infra_ems,
          :foreign_key => "provider_id",
          :class_name  => "EmsOpenstackInfra",
          :autosave    => true
  has_many :cloud_ems,
           :foreign_key => "provider_id",
           :class_name  => "EmsOpenstack",
           :dependent   => :nullify,
           :autosave    => true

  validates :name, :presence => true, :uniqueness => true
end
