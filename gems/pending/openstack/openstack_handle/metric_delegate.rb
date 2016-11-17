module OpenstackHandle
  class MetricDelegate < DelegateClass(Fog::Metric::OpenStack)
    include OpenstackHandle::HandledList
    include Vmdb::Logging

    SERVICE_NAME = "Metric".freeze

    attr_reader :name

    def initialize(dobj, os_handle, name)
      super(dobj)
      @os_handle = os_handle
      @name      = name
    end

    # Ceilometer-like methods provided by Gnocchi backend to serve code expecting Ceilometer API
    def list_meters(filters)
      data = []
      filters.each do |filter|
        next if filter['field'] == 'metadata.instance_id'
        raise "Unexpected Metric filter \"#{filter['field']}\"" unless filter['field'] == 'resource_id'
        res = resources.find_by_id(filter['value'])
        if res.nil?
          $log.warn("OpenstackHandle::MetricDelegate list_meters filter:#{filter} Resource does not exist.")
          next
        end
        data << res.metrics.map { |key, value| {"name" => key, "id" => value} }
      end
      OpenStruct.new(:body => data.flatten)
    end

    def get_statistics(counter_name, options)
      resource_id = options['q'].find { |q| q['field'] == 'resource_id' }['value']
      start = options['q'].find { |q| q['field'] == 'timestamp' && q['op'] == 'gt' }['value']
      stop = options['q'].find { |q| q['field'] == 'timestamp' && q['op'] == 'lt' }['value']
      granularity = 300 # Gnocchi default minimal granularity
      measures = get_resource_metric_measures(resource_id, counter_name, :start => start, :stop => stop, :granularity => granularity).body
      stats = measures.map do |measure|
        {
          'period_end'   => measure[0], # TODO(maufart): Is count with granularity needed here?
          'duration_end' => measure[0],
          'avg'          => measure[2],
        }
      end
      OpenStruct.new(:body => stats)
    end
  end
end
