require "open-uri"
require "mini_magick"

class ImageAttachJob < ApplicationJob
  queue_as :image_attach

  RETRYABLE_HTTP_STATUSES = (500..599).to_a + [429]

  retry_on Errno::ECONNRESET, wait: :exponentially_longer, attempts: 8
  retry_on Net::OpenTimeout, wait: :exponentially_longer, attempts: 5
  retry_on Net::ReadTimeout, wait: :exponentially_longer, attempts: 5
  retry_on SocketError, wait: :exponentially_longer, attempts: 5

  def perform(bgg_id, image_url)
    game = Game.find_by(bgg_id: bgg_id)
    return unless game && image_url.present?

    filename = File.basename(URI.parse(image_url).path)

    if game.image.attached?
      stored_filename = game.image.blob.metadata["source_filename"]
      return if stored_filename == filename
    end

    file = URI.parse(image_url).open
    extension = File.extname(filename).delete(".").downcase
    content_type = extension == "jpg" ? "image/jpeg" : "image/#{extension}"
    resized = begin
      ImageProcessing::MiniMagick
        .source(file)
        .resize_to_limit(1024, 1024)
        .call
    rescue MiniMagick::Error => e
      Rails.logger.error("Failed to process image for bgg_id #{bgg_id} (#{image_url}): #{e.message}")
      Rails.error.report(e, context: { bgg_id: bgg_id, image_url: image_url })
      return # corrupt/unprocessable image — retrying won't fix it
    end

    image_properties = MiniMagick::Image.new(resized.path)
    resized_width  = image_properties.width
    resized_height = image_properties.height

    game.image.attach(
      io: resized,
      filename: filename,
      content_type: content_type,
      identify: false,
      metadata: {
        width: resized_width,
        height: resized_height,
        source_filename: filename,
        analyzed: true
      }
    )

  rescue OpenURI::HTTPError => e
    status = e.io.status.first.to_i
    message = "Image download failed for #{image_url}: #{e.message}"

    if RETRYABLE_HTTP_STATUSES.include?(status)
      Rails.logger.warn(message)
      raise # bubbles up to retry_on-style handling — but see note below
    else
      Rails.logger.error(message)
      Rails.error.report(e, context: { bgg_id: bgg_id, image_url: image_url, status: status })
      # not retryable (404, etc.) — don't fail the job further
    end
  end
end
