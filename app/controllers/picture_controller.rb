class PictureController < ApplicationController
  def show # GET /pictures/:basename
    compressed_id, extension = params[:basename].split('.')
    picture = Picture.find_by_id(Picture.uncompress_id(compressed_id))
    if picture.blank? || extension != picture.extension
      render :nothing => true, :status => 404
    else
      render_picture_content(picture)
    end
  end

  private

  def render_picture_content(picture)
    response.headers['Cache-Control'] = "public"
    response.headers['Content-Type'] = "image/#{picture.extension}"
    response.headers['Content-Disposition'] = "inline"
    render :text => cached_picture_content(picture)
  end

  def cached_picture_content(picture)
    @cache ||= ActiveSupport::Cache.lookup_store(:mem_cache_store)
    image_key = "picture_content_#{picture.compressed_id}"
    picture_content = @cache.read(image_key)
    if picture_content.blank? ||
       picture_content.bytesize != picture.size ||
       Digest::MD5.hexdigest(picture_content) != picture.md5
      picture_content = picture.content
      @cache.write(image_key, picture_content)
    end
    picture_content
  end
end
