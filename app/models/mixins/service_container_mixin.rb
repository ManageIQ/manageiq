module ServiceContainerMixin
  extend ActiveSupport::Concern

  included do
    has_many :container_templates, :through => :service_resources, :source => :resource, :source_type => 'ContainerTemplate'
    private :container_templates, :container_templates=
  end

  def container_template
    container_templates.take
  end

  def container_template=(template)
    self.container_templates = [template].compact
  end

  def container_manager
    container_template.try(:ext_management_system)
  end
end
