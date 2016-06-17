class DialogFieldVisibilityService
  def initialize(
    auto_placement_visibility_service = AutoPlacementVisibilityService.new
  )
    @auto_placement_visibility_service = auto_placement_visibility_service
  end

  def determine_visibility(options)
    field_names_to_hide = []
    field_names_to_show = []

    visibility_hash = @auto_placement_visibility_service.determine_visibility(options[:auto_placement_enabled])
    field_names_to_hide += visibility_hash[:hide]
    field_names_to_show += visibility_hash[:show]

    {:hide => field_names_to_hide.flatten, :edit => field_names_to_show.flatten}
  end
end
