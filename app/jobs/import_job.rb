class ImportJob < ApplicationJob
  queue_as :default

  def perform
    import = BggDataImport.new
    import.run
  end
end
