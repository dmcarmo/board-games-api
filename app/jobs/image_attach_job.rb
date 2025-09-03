class ImageAttachJob < ApplicationJob
  queue_as :image_attach

  retry_on Errno::ECONNRESET, wait: :exponentially_longer, attempts: 8
  retry_on Faraday::TimeoutError, wait: :exponentially_longer, attempts: 5
  retry_on Faraday::ConnectionFailed, wait: :exponentially_longer, attempts: 5

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
    resized = ImageProcessing::MiniMagick
              .source(file)
              .resize_to_limit(1024, 1024)
              .call

    game.image.attach(io: resized, filename: filename, content_type: content_type,
                      metadata: { source_filename: filename })

    game.image.analyze_later
  rescue OpenURI::HTTPError => e
    Rails.logger.warn("Image download failed for #{image_url}: #{e.message}")
    raise # bubbles the error up and marks the job as failed
  end
end
