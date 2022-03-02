require 'sinatra'
require 'sinatra/reloader'
require 'slim'
require 'sassc'
require 'bcrypt'
require 'sqlite3'

require_relative 'database'
require_relative 'functions'


enable :sessions

also_reload 'database.rb'

get '/style.css' do
    scss :'scss/style', style: :compressed
end


get('/') do

    slim(:index)

end

get('/login') do

    slim(:login)

end

get('/store') do

    slim(:store)

end

get('/inventory') do

    slim(:inventory)

end



post('/register') do
    user = params['user']
    pwd = params['password']
    p pwd
    pwd_confirm = params['pwd_confirm']
    db = SQLite3::Database.new('data/database.db')
    result=db.execute('SELECT id FROM User WHERE username=?',user)
    if result.empty?
        if pwd==pwd_confirm
            pwd_digest = BCrypt::Password.create(pwd)
            db.execute('INSERT INTO User (username, password) VALUES(?, ?)', user, pwd_digest)
            #redirect('/welcome')
        else
            #redirect('/error') #Lösenord matchar ej
        end
    else
        #redirect('/login') #User existerar redan
    end
end