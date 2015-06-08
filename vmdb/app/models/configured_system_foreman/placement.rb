module ConfiguredSystemForeman::Placement
  def available_configuration_profiles
    cl_history = configuration_location.try(:path) || []
    co_history = configuration_organization.try(:path) || []
    MiqPreloader.preload(cl_history + co_history, :configuration_profiles => :configuration_architecture)
    cp_no_cl = ConfigurationProfile.includes(:configuration_locations).find(:all, :conditions => {"configuration_locations_configuration_profiles.configuration_profile_id" => nil})
    cp_no_co = ConfigurationProfile.includes(:configuration_organizations).find(:all, :conditions => {"configuration_organizations_configuration_profiles.configuration_profile_id" => nil})
    cp_by_cl = (cl_history.collect(&:configuration_profiles).flatten + cp_no_cl).uniq
    cp_by_co = (co_history.collect(&:configuration_profiles).flatten + cp_no_co).uniq
    (cp_by_cl & cp_by_co).select { |cp| [configuration_architecture, nil].include?(cp.configuration_architecture) }
  end
end
