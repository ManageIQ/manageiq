module ConfiguredSystemForeman::Placement
  def available_configuration_profiles
    cl_history = configuration_location.try(:path) || []
    co_history = configuration_organization.try(:path) || []
    MiqPreloader.preload(cl_history + co_history, :configuration_profiles => :configuration_architecture)
    cp_by_cl = cl_history.collect(&:configuration_profiles).flatten.uniq
    cp_by_co = co_history.collect(&:configuration_profiles).flatten.uniq
    (cp_by_cl & cp_by_co).select { |cp| [configuration_architecture, nil].include?(cp.configuration_architecture) }
  end
end
