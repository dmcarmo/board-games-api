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

  def perform
    csv_io = BggCsvDownloader.call
    result = BggCsvImport.new(csv_io).diff

    limit = ENV["IMPORT_LIMIT"]&.to_i
    new_attrs = limit ? result.new_attrs.first(limit) : result.new_attrs
    new_ids = limit ? result.new_ids.first(limit) : result.new_ids
    existing_attrs = limit ? result.existing_attrs.first(limit) : result.existing_attrs

    new_attrs.each_slice(BATCH_SIZE) { |slice| Game.insert_all(slice) }
    existing_attrs.each_slice(BATCH_SIZE) { |slice| Game.upsert_all(slice, unique_by: :bgg_id) }

    return if new_ids.empty?

    GoodJob::Batch.enqueue do
      new_ids.each_slice(BATCH_SIZE) { |chunk| BggDataImportJob.perform_later(chunk) }
    end
  end
end
