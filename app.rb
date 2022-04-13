require 'sinatra'
require 'sinatra/reloader'
require 'slim'
require 'sassc'
require 'bcrypt'
require 'sqlite3'

require_relative 'model'
require_relative 'functions'


enable :sessions

also_reload 'model.rb', 'functions.rb'

get '/style.css' do
    scss :'scss/style', style: :compressed
end




get('/') do

    slim(:index)

end

get('/register') do

    if session[:user] != nil
        redirect('/store')
    end

    slim(:register)

end

get('/login') do

    if session[:user] != nil
        redirect('/store')
    end

    slim(:login, locals: { error: "", success: ""})

end

get('/logout') do

    session.destroy
    redirect('/login')

end

get('/store') do
    
    catalog = User.LoadItems(nil) 
    catalog.map! do |item|
        Item.from_id(item["id"])
        
    end

    slim(:store, locals: {items: catalog})

end




get('/inventory') do
    items = User.LoadItems(session[:user_id]) 
    
    items.map! do |id|
        Item.from_id(id)
        
    end
    slim(:inventory, locals: {items: items})

end

get('/create') do

    slim(:create)
    
end




post('/register') do
    user = params['user']
    pwd = params['password']
    p pwd
    pwd_confirm = params['pwd_confirm']
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


post('/login') do

    username = params["user"]
    pwd = params["password"]

    user = User.from_username(username)

    if !user
        return slim(:"login", locals: {error: "Användaren finns inte!"}) #Fel användarnamn
    elsif BCrypt::Password.new(user.password_hash) == pwd
        session[:user_id] = user.id
        redirect("/store") 
    else
        return slim(:"login", locals: {error: "Fel lösenord"}) #Fel lösenord
    end

end


post('/create') do

    name = params["name"]
    price = params["price"]

    db.execute("INSERT into Items (name, price) VALUES (?, ?)", name, price)

end


post('/buy/:item_id') do

    item_id = params[:item_id]
    user_id = session[:user_id]

    user_coins = db.execute("SELECT coins FROM User WHERE id = ?", [user_id]).first["coins"]
    item_price = db.execute("SELECT price FROM Items WHERE id = ?", [item_id]).first["price"]

    puts user_coins.class

    puts item_price.class

    if user_coins >= item_price

        remaining_coins =  user_coins - item_price
        db.execute("UPDATE User SET coins = ? WHERE id = ? ", remaining_coins, user_id)
        db.execute("INSERT into UserItemRelation (userid, itemid) VALUES (?, ?)", user_id, item_id)

    end

    redirect(:inventory)

end