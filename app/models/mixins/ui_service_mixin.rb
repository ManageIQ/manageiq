module UiServiceMixin
  def icons
    {
      :ContainerReplicator     => {:type => "glyph", :icon => "\uE624", :fontfamily => "PatternFlyIcons-webfont"}, # pficon-replicator
      :ContainerGroup          => {:type => "glyph", :icon => "\uF1B3", :fontfamily => "FontAwesome"},             # fa-cubes
      :ContainerNode           => {:type => "glyph", :icon => "\uE621", :fontfamily => "PatternFlyIcons-webfont"}, # pficon-container-node
      :ContainerService        => {:type => "glyph", :icon => "\uE61E", :fontfamily => "PatternFlyIcons-webfont"}, # pficon-service
      :ContainerRoute          => {:type => "glyph", :icon => "\uE625", :fontfamily => "PatternFlyIcons-webfont"}, # pficon-route
      :Container               => {:type => "glyph", :icon => "\uF1B2", :fontfamily => "FontAwesome"},             # fa-cube
      :Host                    => {:type => "glyph", :icon => "\uE600", :fontfamily => "PatternFlyIcons-webfont"}, # pficon-screen
      :Vm                      => {:type => "glyph", :icon => "\uE90f", :fontfamily => "PatternFlyIcons-webfont"}, # pficon-virtual-machine
      :MiddlewareDatasource    => {:type => "glyph", :icon => "\uF1C0", :fontfamily => "FontAwesome"},             # fa-database
      :MiddlewareDeployment    => {:type => "glyph", :icon => "\uE603", :fontfamily => "icomoon"},                 # product-report
      :MiddlewareDeploymentEar => {:type => "glyph", :icon => "\uE626", :fontfamily => "icomoon"},                 # product-file-ear-o
      :MiddlewareDeploymentWar => {:type => "glyph", :icon => "\uE627", :fontfamily => "icomoon"},                 # product-file-war-o
      :Kubernetes              => {:type => "image", :icon => provider_icon(:Kubernetes)},
      :Openshift               => {:type => "image", :icon => provider_icon(:Openshift)},
      :OpenshiftEnterprise     => {:type => "image", :icon => provider_icon(:OpenshiftEnterprise)},
      :Atomic                  => {:type => "image", :icon => provider_icon(:Atomic)},
      :AtomicEnterprise        => {:type => "image", :icon => provider_icon(:AtomicEnterprise)},
    }
  end

  def provider_icon(provider_type)
    file_name = "svg/vendor-#{provider_type.to_s.underscore.downcase}.svg"
    ActionController::Base.helpers.image_path(file_name)
  end
end
