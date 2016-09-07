module Api
  class AuthenticationError < StandardError; end
  class Forbidden < StandardError; end
  class BadRequestError < StandardError; end
  class NotFound < StandardError; end
  class UnsupportedMediaTypeError < StandardError; end
end
