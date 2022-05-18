require 'sinatra'
require 'sinatra/reloader'
require 'slim'
require 'sassc'
require 'bcrypt'
require 'sqlite3'
require 'json'


require_relative 'model'
require_relative 'functions'


enable :sessions

also_reload 'model.rb', 'functions.rb'

get '/style.css' do
    scss :'scss/style', style: :compressed
end


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

    slim(:"/user/new") 


end

get('/login') do

    if session[:user] != nil
        redirect('/store')
    end

    slim(:"/user/login", locals: { error: "", success: ""})

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

    p items

    slim(:inventory, locals: {items: items})

end

get('admin/item/new') do

    if User.from_id(session[:user_id]).rank >= 1
        slim(:"/item/new")
    else
        redirect('/store')
    end

    
end

get('/admin/item/remove') do

    slim(:"/item/remove", locals: { feedback: "" })

end

get('/admin/user/edit') do

    slim(:"/user/edit", locals: { feedback: "" })
    
end



get('/user/:id') do 

    userid = params[:id]
    user = User.from_id(userid)
    

    raise Sinatra::NotFound unless user

    items = User.LoadItems(user.id) 
    
    items.map! do |id|
        
        Item.from_id(id)

    end

    slim(:"/user/index", locals: { user: user, items: items} ) 

end


get('/trades') do

    if current_user.id != nil
        trades = Trades.list(current_user.id)
    end
    feedback = ""
    slim(:"/trade/index", locals: { trades: trades, feedback: feedback } )

end


get('/trade/:id') do

    userid = params[:id]
    user = User.from_id(userid)

    raise Sinatra::NotFound unless user

    items = User.LoadItems(user.id) 
    myitems = User.LoadItems(current_user.id) 

    items.map! do |id|
        Item.from_id(id)
        
    end

    myitems.map! do |id|

        Item.from_id(id)
        
    end

    slim(:"/trade/new", locals: { user: user, items: items, myitems: myitems} ) 

end




post('/register') do
    user = params['user']
    pwd = params['password']

    pwd_confirm = params['pwd_confirm']
    result = User.select_id(user)
    if result.empty?
        if pwd==pwd_confirm
            pwd_digest = User.create_password(pwd)
            User.create(user, pwd_digest)
            session[:user_id] = User.from_username(user).id
            redirect('/store')
        else
            redirect('/register') #Lösenord matchar ej
        end
    else
        redirect('/login') #User existerar redan
    end
end


post('/login') do

    username = params["user"]
    pwd = params["password"]

    user = User.from_username(username)

    if !user
        return slim(:login, locals: {error: "Användaren finns inte!"}) #Fel användarnamn
    elsif User.check_password(user.password_hash, pwd)
        session[:user_id] = user.id
        redirect("/store") 
    else
        return slim(:login, locals: {error: "Fel lösenord"}) #Fel lösenord
    end

end


post('/items') do

    if User.from_id(session[:user_id]).rank >= 1

        name = params["name"]
        price = params["price"]
        image_url = params["image_url"]

        Item.create(name, price, image_url)
    
    end

    redirect('/store')

end


post('/user/update') do 

    if User.from_id(session[:user_id]).rank >= 1


        username = params["username"]
        coins = params["coins"]

        #user = db.execute("SELECT username FROM User WHERE username = ?", username)
        user = User.select_id(username).first["id"]
        p user
        if ! user.to_i != 0 && coins.to_i != 0
            User.setcoins(coins, user)
            slim(:"/user/edit", locals: {feedback: "Coins för användaren: #{username}, är nu #{coins}"})

        else

            slim(:"/user/edit", locals: {feedback: "Användaren fanns inte eller så angav du inte korrekt datatyp för coins"})

        end

    else

        redirect('/store')

    end


end


post('/item/remove') do 

    if User.from_id(session[:user_id]).rank >= 1

        item_name = params["item"]

        item = Item.item_name(item_name)
        itemid = Item.item_id(item_name)

        if item.length >= 1

            Item.delete(item_name, itemid)

            slim(:"/item/remove", locals: {feedback: "Item togs bort"})

        else
            slim(:"/item/remove", locals: {feedback: "Item fanns ej"})
        end
    else
        
        redirect('/store')

    end

end


get('/users') do

    users = User.search(params["query"])
    slim(:"/user/users", locals: {users: users})

end



post('/item/:id/buy') do 

    item_id = params[:id]
    user_id = session[:user_id]

    p user_id

    user_coins = User.from_id(session[:user_id]).coins
    item_price = Item.price(item_id)


    if user_coins >= item_price

        remaining_coins = user_coins - item_price
        User.setcoins(remaining_coins, user_id)
        User.recieve_item(user_id, item_id)

    end

    redirect(:inventory)

end


post('/trades') do

    
    fromuserid = "U#{current_user.id}"
    touserid = "U#{params[:userid].to_i}"
    p touserid

    from_items = Array.new
    to_items = Array.new

    trade = params.to_a

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

    Trades.create(from_items.to_s, to_items.to_s)

    trades = []


    slim(:"/trade/index", locals: {feedback: "Traden skickades", trades: trades})



end

post('/trade/:id/accept') do

    tradeid = params[:id]
    reciever = session[:user_id]
    p tradeid
    trade = Trades.select(tradeid)
    if trade != nil

        if Trades.exchange(trade, tradeid, reciever)

            Trades.delete(tradeid, reciever)
            trades = []
            slim(:"/trade/index", locals: {feedback: "Byte lyckades", trades: trades})

        else

            trades = []
            Trades.delete(tradeid, reciever)
            slim(:"/trade/index", locals: {feedback: "Antingen äger du inte bytet, eller så har föremålen redan bytts bort.", trades: trades})

        end

    else

        trades = []

        slim(:"/trade/index", locals: {feedback: "Bytet fanns ej", trades: trades})
    end

    

end

post('/trade/:id/decline') do

    tradeid = params[:id]
    user = current_user.id
    Trades.delete(tradeid, user)

end