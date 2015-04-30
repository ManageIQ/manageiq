module ConfiguredSystemForeman::Placement
  def available_configuration_profiles
    cp_by_cl = configuration_location.path.collect(&:configuration_profiles).flatten!.uniq
    cp_by_co = configuration_organization.path.collect(&:configuration_profiles).flatten!.uniq
    (cp_by_cl & cp_by_co).select { |cp| [configuration_architecture, nil].include?(cp.configuration_architecture) }
  end
end
