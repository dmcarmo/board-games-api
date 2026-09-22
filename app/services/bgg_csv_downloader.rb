require "stringio"

class BggCsvDownloader
  LOGIN_URL = "https://boardgamegeek.com/login/api/v1"
  DOWNLOAD_URL = "https://boardgamegeek.com/data_dumps/bg_ranks"

  class DownloadFailed < StandardError; end

  class LoginFailed < StandardError
    attr_reader :status

    def initialize(message, status:)
      super(message)
      @status = status
    end

    def retryable?
      status.nil? || status.to_i >= 500
    end
  end

  def self.call
    session_data = bgg_login
    cookie = build_cookie(session_data)

    csv_url = fetch_csv_url(cookie)
    fetch_csv_file(csv_url)
  end

  # --- private ---

  def self.fetch_csv_file(csv_url)
    response = Faraday.get(csv_url)
    raise DownloadFailed, "status #{response.status}" unless response.success?

    Zip::InputStream.open(StringIO.new(response.body)) do |stream|
      stream.get_next_entry
      StringIO.new(stream.read.force_encoding("UTF-8"))
    end
  end
  private_class_method :fetch_csv_file

  def self.fetch_csv_url(cookie)
    response = Faraday.get(DOWNLOAD_URL, {}, {"Cookie" => cookie})
    unless response.success?
      raise DownloadFailed, "status #{response.status}"
    end
    url = Nokogiri.parse(response.body).at_css("#maincontent a")&.attr("href")

    raise DownloadFailed, "could not find download link on page" if url.nil?

    url
  end
  private_class_method :fetch_csv_url

  def self.bgg_login
    response = Faraday.post(
      LOGIN_URL,
      {credentials: {username: ENV["BGG_USERNAME"], password: ENV["BGG_PASSWORD"]}}.to_json,
      "Content-Type" => "application/json"
    )
    unless response.success?
      raise LoginFailed.new("status #{response.status}", status: response.status)
    end

    extract_session(response)
  rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
    raise LoginFailed.new(e.message, status: nil)
  end
  private_class_method :bgg_login

  def self.extract_session(response)
    cookie = response.headers["set-cookie"]
    {
      id: cookie[/SessionID=([a-z0-9]+)/, 1],
      username: cookie[/username=([a-z0-9]+)/, 1],
      password: cookie[/password=([a-z0-9]+)/, 1]
    }
  end
  private_class_method :extract_session

  def self.build_cookie(session)
    "SessionID=#{session[:id]};bggusername=#{session[:username]};bggpassword=#{session[:password]}"
  end
  private_class_method :build_cookie
end