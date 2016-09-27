module Api
  class PicturesController < BaseController
    def create_resource(_type, _id, data)
      data['content'] = Base64.decode64(data['content'])
      picture = Picture.create(data)
      raise BadRequestError,
            "Failed to create Picture - #{picture.errors.full_messages.join(', ')}" unless picture.valid?
      picture
    end
  end
end
