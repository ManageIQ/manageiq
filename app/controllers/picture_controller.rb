class PictureController < ApplicationController
  def show # GET /pictures/:basename
    compressed_id, extension = params[:basename].split('.')
    picture = Picture.find_by_id(from_cid(compressed_id))
    if picture && picture.extension == extension
      render_picture_content(picture)
    else
      head :not_found
    end
  end

  private

  def render_picture_content(picture)
    response.headers['Cache-Control'] = "public"
    response.headers['Content-Type'] = "image/#{picture.extension}"
    response.headers['Content-Disposition'] = "inline"
    render :text => picture.content
  end
end
