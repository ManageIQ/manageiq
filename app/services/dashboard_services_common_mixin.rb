module DashboardServicesCommonMixin
  def status_obj_for(entity)
    {
      :count        => @record.try(entity).count,
      :errorCount   => 0,
      :warningCount => 0,
      :href         => url_to_entity(entity)
    }
  end

  def obj_statuses(entities)
    obj_statuses = {}

    entities.each do |entity|
      obj_statuses[entity] = status_obj_for(entity)
    end

    obj_statuses
  end

  def url_to_entity(entity)
    @controller.url_for(:action     => 'show',
                        :id         => @id,
                        :display    => entity.to_s.pluralize,
                        :controller => @record.class.base_class.name.underscore.to_sym)
  end
end
