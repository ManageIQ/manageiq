module ConfiguredSystemForeman::Placement
  def available_configuration_profiles
    return [] if configuration_location.nil? || configuration_organization.nil?
    cl_path_ids = configuration_location.path.collect(&:id)
    co_path_ids = configuration_organization.path.collect(&:id)
    ConfigurationProfile.joins(:configuration_locations, :configuration_organizations)
      .includes(:configuration_architecture)
      .where(
        :configuration_locations_configuration_profiles     => {:configuration_location_id     => cl_path_ids},
        :configuration_organizations_configuration_profiles => {:configuration_organization_id => co_path_ids},
      )
      .select { |cp| [configuration_architecture, nil].include?(cp.configuration_architecture) }
  end
end
