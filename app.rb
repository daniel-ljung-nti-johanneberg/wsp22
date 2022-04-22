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



# p User.LoadItems(3)

get('/') do

    
    if current_user
        return redirect('/store')
    end

    slim :index, :layout => false


end

get('/register') do

    if current_user
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
    redirect('/')

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

get('/removeitem') do

    slim(:removeitem, locals: { feedback: "" })
    
end

get('/coinset') do

    slim(:setcoins, locals: { feedback: "" })
    
end

get('/search') do

    slim(:search, locals: { users: ""})
    
end

get('/users/:id') do

    userid = params[:id]
    user = User.from_id(userid)

    raise Sinatra::NotFound unless user

    items = User.LoadItems(user.id) 
    
    items.map! do |id|
        
        Item.from_id(  )

    end

    slim(:profile, locals: { user: user, items: items} ) 

end


get('/trades') do

    userid = session[:user_id]

    p "test"

    trades = db.execute("SELECT * FROM Trades WHERE reciever LIKE '%U#{userid}%'").first


    slim(:trades, locals: { trades: trades } )

end


get('/trade/:id') do

    userid = params[:id]
    user = User.from_id(userid)

    raise Sinatra::NotFound unless user

    items = User.LoadItems(user.id) 
    myitems = User.LoadItems(current_user.id) 
    p current_user.id
    items.map! do |id|
        Item.from_id(id)
        
    end

    myitems.map! do |id|

        Item.from_id(id)
        
    end

    slim(:sendtrade, locals: { user: user, items: items, myitems: myitems} ) 

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
            session[:user_id] = User.from_username(user).id
            redirect('/store')
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
        return slim(:login, locals: {error: "Användaren finns inte!"}) #Fel användarnamn
    elsif BCrypt::Password.new(user.password_hash) == pwd
        session[:user_id] = user.id
        redirect("/store") 
    else
        return slim(:login, locals: {error: "Fel lösenord"}) #Fel lösenord
    end

end


post('/create') do

    name = params["name"]
    price = params["price"]
    image_url = params["image_url"]

    db.execute("INSERT into Items (name, price, image_url) VALUES (?, ?, ?)", name, price, image_url)

end


post('/setcoins') do

    

   username = params["username"]
   coins = params["coins"]

   user = db.execute("SELECT username FROM User WHERE username = ?", username)
   
   if user.length >= 1 && coins.to_i != 0

    db.execute("UPDATE User SET coins = ? WHERE username = ? ",coins,username)
    slim(:setcoins, locals: {feedback: "Coins för användaren: #{username}, är nu #{coins}"})

   else
    
    slim(:setcoins, locals: {feedback: "Användaren fanns inte eller så angav du inte korrekt datatyp"})

   end



end


post('/removeitem') do

    item_name = params["item"]

    item = db.execute("SELECT name FROM Items WHERE name = ?", item_name)
    itemid = db.execute("SELECT id FROM Items WHERE name = ?", item_name).first["id"]
    p itemid
    
    if item.length >= 1

        db.execute("DELETE FROM Items WHERE name = ?", item_name)

        db.execute("DELETE FROM UserItemRelation WHERE itemid = ?", itemid)

        slim(:removeitem, locals: {feedback: "Item togs bort"})

    else
        slim(:removeitem, locals: {feedback: "Item fanns ej"})
    end

end


post('/search') do

    users = User.search(params["query"])
    slim(:search, locals: {users: users})

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


post('/sendtrade/:userid') do

    fromuserid = "U#{current_user.id}"
    touserid = "U#{params[:userid].to_i}"

    from_items = Array.new
    to_items = Array.new

    trade = params.to_a

    p trade

    trade.each do |item| 

        if item[1] == "on"

            info = item[0]

            if info[0] == "1"
    
                itemid = info[1..-1]
                itemid = itemid[0..-5]
                to_items << itemid.to_i
    
            else

                itemid = info[1..-1]
                itemid = itemid[0..-5]
                from_items << itemid.to_i

            end
    
        end

     
    end

    from_items << fromuserid
    to_items << touserid

    p from_items.to_s
    p to_items.to_s

    db.execute('INSERT into Trades (sender, reciever) VALUES (?, ?)', from_items.to_s, to_items.to_s)

    return


end