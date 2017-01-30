module Api
  class PicturesController < BaseController
    def create_resource(_type, _id, data)
      validate_picture_data(data)
      data['content'] = Base64.decode64(data['content'])
      Picture.create(data)
    rescue => err
      raise BadRequestError, "Failed to create Picture - #{err}"
    end

    private

    def validate_picture_data(data)
      raise 'requires an extension' unless data['extension']
      if data['content']
        raise 'content is not base64' unless base64_content?(data['content'])
      else
        raise 'requires content'
      end
    end

    def base64_content?(content)
      (content.length % 4).zero? && (content =~ %r{^[A-Za-z0-9+\/=]+\Z})
    end
  end
end
