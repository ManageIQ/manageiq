class HawkularProxyService
  include UiServiceMixin

  def initialize(provider_id, controller)
    @provider_id = provider_id
    @controller = controller

    @params = controller.params
    @ems = ManageIQ::Providers::ContainerManager.find(@provider_id) unless @provider_id.blank?
    @tenant = @params['tenant'] || '_system'
  end

  def client
    ManageIQ::Providers::Kubernetes::ContainerManager::MetricsCapture::HawkularClient.new(@ems, @tenant)
  end

  def data(query)
    case query
    when 'metric_definitions'
      { :metric_definitions => metric_definitions }
    when 'metric_tags'
      { :metric_tags => metric_tags }
    when 'get_data'
      { :id   => @params['metric_id'],
        :data => get_data(@params['metric_id']).compact }
    else
      {}
    end
  rescue StandardError => e
    { :error => e }
  end

  def metric_definitions
    tags = @params['tags'].blank? ? nil : JSON.parse(@params['tags'])
    tags = nil if tags == {}
    definitions = client.gauges.query(tags).compact.map { |m| m.json if m.json }.sort { |a, b| a["id"] <=> b["id"] }

    definitions[0..100]
  end

  def metric_tags
    metric_definitions.map { |x| x["tags"].keys if x["tags"] }.compact.flatten.uniq.sort
  end

  def get_data(id)
    ends = @params['ends'] || (DateTime.now.to_i * 1000)
    starts = @params['starts'] || (ends - 8 * 60 * 60 * 1000)
    bucket_duration = @params['bucket_duration'] || nil
    order = @params['order'] || 'ASC'
    limit = @params['limit'].to_i || 500

    data = client.gauges.get_data(id,
                                  :limit          => limit,
                                  :starts         => starts.to_i,
                                  :ends           => ends.to_i,
                                  :bucketDuration => bucket_duration,
                                  :order          => order)
    data[0..(limit - 1)]
  end
end
