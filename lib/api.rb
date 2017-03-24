module Api
  ApiError = Class.new(StandardError)
  AuthenticationError = Class.new(ApiError)
  ForbiddenError = Class.new(ApiError)
  BadRequestError = Class.new(ApiError)
  NotFoundError = Class.new(ApiError)
  UnsupportedMediaTypeError = Class.new(ApiError)

  def self.encrypted_attribute?(attr)
    Environment.normalized_attributes[:encrypted].key?(attr.to_s) || attr.to_s.include?('password')
  end
end
