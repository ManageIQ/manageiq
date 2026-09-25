module ProviderWorkerRunnerMixin
  extend ActiveSupport::Concern

  private

  def worker_options
    ems          = @ems || ExtManagementSystem.find(@cfg[:ems_id])
    all_managers = [ems] + ems.child_managers

    super.merge(
      :ems => all_managers.map do |manager|
        manager.attributes.merge(
          "ems_type"        => manager.class.ems_type,
          "endpoints"       => manager.endpoints,
          "authentications" => manager.authentications
        )
      end
    )
  end
end
