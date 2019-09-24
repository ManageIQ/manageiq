module Vmdb
  class Productization
    def prepare
      prepare_asset_paths
      prepare_asset_precompilation
    end

    private

    # Prepend the productization/assets directories to the asset paths.
    def prepare_asset_paths
      pattern = Rails.root.join("productization", "assets", "*")
      paths   = Dir.glob(pattern).select { |f| File.directory?(f) }
      Rails.application.config.assets.paths.unshift(*paths)
    end

    # sprockets-rails is very strict about the path to assets being in Rails.root.join("app/assets")
    #   so we must duplicate it with our new paths.
    LOOSE_APP_ASSETS = lambda do |logical_path, filename|
      filename.start_with?(::Rails.root.join("productization/assets").to_s) &&
        !['.js', '.css', ''].include?(File.extname(logical_path))
    end

    def prepare_asset_precompilation
      Rails.application.config.assets.precompile += [LOOSE_APP_ASSETS]
      Rails.application.config.assets.precompile += %w(productization.css productization.js)
    end
  end
end
