module Api
  class PicturesController < BaseController
    def create_resource(_type, _id, data)
      raise 'requires content' unless data['content']
      Picture.new(data.except('content')).tap do |picture|
        picture.content = Base64.strict_decode64(data['content'])
        picture.save!
      end
    rescue => err
      raise BadRequestError, "Failed to create Picture - #{err}"
    end
  end
end
