module Api
  class MetricsController < Api::BaseController
    skip_before_action :verify_authenticity_token

    def options
      head(:ok)
    end

    def index
      render :json => {
        :name      => "Metrics RESTful API",
        :name_full => I18n.t("product.name_full"),
        :copyright => I18n.t("product.copyright")
      }
    end

    def gauges
      keys = params["ids"] || []
      render :json => keys.map { |key| { :id => key, :data => data_for_key(key) } }
    end

    def metrics
      render :json => MetricsController::Events.metrics +
                      MetricsController::Inventory.metrics +
                      MetricsController::Rollups.metrics
    end

    private

    def start_time
      params["start"].blank? ? 8.hours.ago : Time.at(params["start"].to_i / 1000).utc.to_datetime
    end

    def end_time
      params["end"].blank? ? 0.hours.ago : Time.at(params["end"].to_i / 1000).utc.to_datetime
    end

    def data_for_key(key)
      key_scan = key.scan(%r{^([^\/]*)\/([^\/]*)\/([^\/]*)$})
      starts, ends = start_time, end_time

      unless key_scan.empty?
        type, name, metric_name = key_scan[0]

        if type == 'event'
          MetricsController::Events.data_for_key(name, metric_name, starts, ends)
        elsif MetricsController::Inventory.keys.any? { |s| s.include?(metric_name) }
          MetricsController::Inventory.send("data_for_key_#{type}", name, metric_name)
        else
          MetricsController::Rollups.send("data_for_key_#{type}", name, metric_name, starts, ends)
        end
      end
    end
  end
end
