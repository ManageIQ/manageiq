module ProviderWorkerRunnerMixin
  extend ActiveSupport::Concern

  private

  def worker_options
    ems          = ExtManagementSystem.find(@cfg[:ems_id])
    all_managers = [ems] + ems.child_managers

    super.merge(
      :ems => all_managers.map do |manager|
        manager.attributes.merge(
          "endpoints"       => manager.endpoints,
          "authentications" => manager.authentications
        )
      end
    )
  end
end
