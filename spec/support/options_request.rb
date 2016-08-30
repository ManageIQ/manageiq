module ActionDispatch::Integration::RequestHelpers
  def options(path, headers = nil)
    process :options, path, :headers => headers
  end
end
