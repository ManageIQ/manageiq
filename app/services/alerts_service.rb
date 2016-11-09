class AlertsService
  include UiServiceMixin

  def initialize(controller)
    @controller = controller
  end

  def all_data
    {
      :alerts => alerts
    }.compact
  end

  def alerts
    result = {}
    result.values
  end
end
