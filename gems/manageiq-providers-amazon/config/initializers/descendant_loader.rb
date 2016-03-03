# make sure STI models are recognized
DescendantLoader.instance.descendants_paths << ManageIQ::Providers::Amazon::Engine.config.root.join('app/models')
