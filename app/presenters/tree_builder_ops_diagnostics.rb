class TreeBuilderOpsDiagnostics < TreeBuilderOps
  private

  def tree_init_options(_tree_name)
    {
      :open_all => true,
      :leaf     => "Diagnostics"
    }
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:autoload => true)
  end

  def root_options
    region = MiqRegion.my_region
    title =  _("%{product} Region: %{region_description} [%{region}]") % {:region_description => region.description,
                                                                          :region             => region.region,
                                                                          :product            => I18n.t('product.name')}
    [title, title, '100/miq_region.png']
  end
end
