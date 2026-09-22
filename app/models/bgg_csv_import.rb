class BggCsvImport
  Result = Struct.new(:new_ids, :existing_ids, :new_attrs, :removed_ids, keyword_init: true)

  def initialize(csv_io)
    @csv_io = csv_io
  end

  def diff
    rows = CSV.parse(@csv_io.string, headers: true)
    csv_data = rows.index_by { |r| r["id"].to_i }
    csv_ids = csv_data.keys.to_set
    db_ids = Game.pluck(:bgg_id).to_set

    new_ids = csv_ids - db_ids

    Result.new(
      new_ids: new_ids,
      existing_ids: csv_ids & db_ids,
      removed_ids: db_ids - csv_ids,
      new_attrs: new_ids.map { |id| attrs_from_csv(csv_data[id]) }
    )
  end

  def attrs_from_csv(row)
    { bgg_id: row["id"].to_i, name: row["name"], year_published: row["yearpublished"], rank: row["rank"].to_i, bayesian_rating: row["bayesaverage"].to_f, average_rating: row["average"].to_f, created_at: Time.current, updated_at: Time.current }
  end
end
