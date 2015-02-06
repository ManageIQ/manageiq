class EmsContainer < ExtManagementSystem
  SUBCLASSES = %w(
    EmsKubernetes
  )

  def self.types
    subclasses.collect(&:ems_type)
  end

  def self.supported_subclasses
    subclasses
  end

  def self.supported_types
    types
  end
end
