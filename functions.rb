def is_logged_in


    session[:userid] != nil
    

end

def db
    _db = SQLite3::Database.new("data/database.db")
    _db.results_as_hash = true
    _db
end