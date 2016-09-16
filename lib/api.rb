module Api
  ApiError = Class.new(StandardError)
  AuthenticationError = Class.new(ApiError)
  Forbidden = Class.new(ApiError)
  BadRequestError = Class.new(ApiError)
  NotFound = Class.new(ApiError)
  UnsupportedMediaTypeError = Class.new(ApiError)
end
