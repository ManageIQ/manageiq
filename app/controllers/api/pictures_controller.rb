module Api
  class PicturesController < BaseController
    def create_resource(_type, _id, data)
      Picture.create_from_base64(data)
    rescue => err
      raise BadRequestError, "Failed to create Picture - #{err}"
    end
  end
end
