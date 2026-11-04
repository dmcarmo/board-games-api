class ImportJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 1_000

  retry_on BggCsvDownloader::DownloadFailed, wait: :polynomially_longer, attempts: 5

  rescue_from BggCsvDownloader::LoginFailed do |error|
    if error.retryable?
      retry_job wait: 5.minutes
    else
      Rails.error.report(error)
      # or: SystemMailer.import_login_failed(error.message).deliver_later
    end
  end

  def perform(full_update: false)
    limit = ENV["IMPORT_LIMIT"]&.to_i

    if full_update == false
      csv_io = BggCsvDownloader.call
      result = BggCsvImport.new(csv_io).diff

      new_attrs = limit ? result.new_attrs.first(limit) : result.new_attrs
      new_ids = limit ? result.new_ids.first(limit) : result.new_ids
      existing_attrs = limit ? result.existing_attrs.first(limit) : result.existing_attrs

      new_attrs.each_slice(BATCH_SIZE) { |slice| Game.insert_all(slice) }
      existing_attrs.each_slice(BATCH_SIZE) { |slice| Game.upsert_all(slice, unique_by: :bgg_id) }

      update_ids = new_ids
    else
      ids = Game.pluck(:bgg_id)
      update_ids = limit ? ids.first(limit) : ids
    end

    return if update_ids.empty?

    GoodJob::Batch.enqueue do
      update_ids.each_slice(BATCH_SIZE) { |chunk| BggDataImportJob.perform_later(chunk) }
    end
  end
end
