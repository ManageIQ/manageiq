class ApplicationHelper::Toolbar::DriftCenter < ApplicationHelper::Toolbar::Basic
  button_group('drift_tasks', [
    {
      :buttonTwoState => "drift_all",
      :icon         => "product product-compare_all fa-lg",
      :title        => N_("All attributes"),
      :url          => "drift_all",
      :url_parms    => "?id=\#{$vms_comp}&compare_task=all&db=\#{@compare_db}&id=\#{@drift_obj.id}",
    },
    {
      :buttonTwoState => "drift_diff",
      :icon         => "product product-compare_diff fa-lg",
      :title        => N_("Attributes with different values"),
      :url          => "drift_differences",
      :url_parms    => "?id=\#{$vms_comp}&compare_task=different&db=\#{@compare_db}&id=\#{@drift_obj.id}",
    },
    {
      :buttonTwoState => "drift_same",
      :icon         => "product product-compare_same fa-lg",
      :title        => N_("Attributes with same values"),
      :url          => "drift_same",
      :url_parms    => "?id=\#{$vms_comp}&compare_task=same&db=\#{@compare_db}&id=\#{@drift_obj.id}",
    },
  ])
  button_group('compare_mode', [
    {
      :buttonTwoState => "driftmode_details",
      :icon         => "fa fa-bars fa-lg",
      :title        => N_("Details Mode"),
      :url          => "drift_mode",
    },
    {
      :buttonTwoState => "driftmode_exists",
      :icon         => "product product-exists fa-lg",
      :title        => N_("Exists Mode"),
      :url          => "drift_mode",
    },
  ])
end
