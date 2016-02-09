class ApplicationHelper::Toolbar::CompareCenter < ApplicationHelper::Toolbar::Basic
  button_group('comapre_tasks', [
    {
      :buttonTwoState => "compare_all",
      :icon         => "product product-compare_all fa-lg",
      :title        => N_("All attributes"),
      :url          => "compare_miq_all",
      :url_parms    => "?id=\#{$vms_comp}&compare_task=all",
    },
    {
      :buttonTwoState => "compare_diff",
      :icon         => "product product-compare_diff fa-lg",
      :title        => N_("Attributes with different values"),
      :url          => "compare_miq_differences",
      :url_parms    => "?id=\#{$vms_comp}&compare_task=different",
    },
    {
      :buttonTwoState => "compare_same",
      :icon         => "product product-compare_same fa-lg",
      :title        => N_("Attributes with same values"),
      :url          => "compare_miq_same",
      :url_parms    => "?id=\#{$vms_comp}&compare_task=same",
    },
  ])
  button_group('compare_mode', [
    {
      :buttonTwoState => "comparemode_details",
      :icon         => "fa fa-bars fa-lg",
      :title        => N_("Details Mode"),
      :url          => "compare_mode",
    },
    {
      :buttonTwoState => "comparemode_exists",
      :icon         => "product product-exists fa-lg",
      :title        => N_("Exists Mode"),
      :url          => "compare_mode",
    },
  ])
end
