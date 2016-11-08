class Chargeback
  class RatesCache
    def get(perf)
      @rates ||= {}
      @rates[perf.hash_features_affecting_rate] ||=
        begin
          prefix = tag_prefix(perf)
          ChargebackRate.get_assigned_for_target(perf.resource,
                                                 :tag_list => perf.tag_list_reconstruct.map! { |t| prefix + t },
                                                 :parents  => perf.parents_determining_rate)
        end
    end

    private

    def tag_prefix(perf)
      case perf.resource_type
      when Container.name        then 'container_image'
      when VmOrTemplate.name     then 'vm'
      when ContainerProject.name then 'container_project'
      end
    end
  end
end
