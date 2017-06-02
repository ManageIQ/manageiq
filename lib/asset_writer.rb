class AssetWriter
  attr_reader :asset, :target_path

  delegate :logical_path, :digest_path, :to => :asset

  def initialize(asset_path, target_dir)
    @asset = Rails.application.assets.find_asset(asset_path)

    raise ArgumentError, "No asset found for that path" unless @asset

    @target_dir = target_dir
    @target_path = Rails.root.join(target_dir, @asset.digest_path)
  end

  def write
    unless file_exists?
      prep_target
      File.write(target_path, asset.source)
    end

    target_path
  end

  def file_exists?
    File.exist?(target_path)
  end

  private

  def prep_target
    FileUtils.mkdir_p(@target_dir)
  end
end
