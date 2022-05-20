require 'sinatra'
require 'sinatra/reloader'
require 'slim'
require 'sassc'
require 'bcrypt'
require 'sqlite3'
require 'json'
require_relative './model.rb'
require_relative 'functions'

enable :sessions

also_reload 'model.rb', 'functions.rb'

get '/style.css' do
    scss :'scss/style', style: :compressed
end

# Index of the page if user is not logged in, else redirects to Store

get('/') do

    
    if current_user
        return redirect('/store')
    end

    slim :index, :layout => false


end


# Register page if user is not logged in, else redirects to Store
get('/register') do

    if current_user
        redirect('/store')
    end

    slim(:"/user/new", locals: { error: "", success: ""})


end

# Login page if user is not logged in, else redirects to Store
get('/login') do

    if session[:user] != nil
        redirect('/store')
    end

    slim(:"/login", locals: { error: "", success: ""})

end

# Lougout - session destroy
get('/logout') do

    session.destroy
    redirect('/')

end

# Loads items from DB and displays in store
get('/store') do
    catalog = User.LoadItems(nil) 
    catalog.map! do |item|
        Item.from_id(item["id"])
        
    end

    slim(:store, locals: {items: catalog})

end

# Loads current user's items and displays if logged in else redirects to register
get('/inventory') do

    items = []

    if current_user.class != NilClass
        items = User.LoadItems(session[:user_id]) 
    
        items.map! do |id|
            Item.from_id(id)
        end
    
    else
        redirect("/register")
    end

    slim(:inventory, locals: {items: items})

end

# Upload item page, if user is admin
get('/admin/item/new') do

    if User.from_id(session[:user_id]).rank >= 1
        slim(:"/item/new", locals: {feedback: ""})
    else
        redirect('/store')
    end

end

# Remove item page, if user is admin
get('/admin/item/remove') do

    if User.from_id(session[:user_id]).rank >= 1
        slim(:"/item/remove", locals: { feedback: "" })
    else
        redirect('/store')
    end

end

# Edit user page, if user is admin
get('/admin/user/edit') do

    if User.from_id(session[:user_id]).rank >= 1
        slim(:"/user/edit", locals: { feedback: "" })
    else
        redirect('/store')
    end


end


# Profile page of user
# @param userid [Integer]
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

# Trades page if user is logged in else redirects to register
get('/trades') do

    trades = []
    if current_user.class != NilClass
        trades = Trades.list(current_user.id)
    else
        redirect("/register")
    end
    feedback = ""
    slim(:"/trade/index", locals: { trades: trades, feedback: feedback } )

end

# Trade a User, view their items & current user's
# @param userid [Integer]
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

# Register users if validation goes through, and assigns a session
# @param user [String]
# @param pwd [String]
post('/register') do
    user = params['user']
    pwd = params['password']

    pwd_confirm = params['pwd_confirm']
    result = User.select_id(user)
    if result.empty?
        if pwd==pwd_confirm
            if lengthvalidation(user) && lengthvalidation(pwd)
                if check_quality(pwd) == true
                    pwd_digest = User.create_password(pwd)
                    User.create(user, pwd_digest)
                    session[:user_id] = User.from_username(user).id
                    redirect('/store')
                else
                    return slim(:"/user/new", locals: {error: "Du har skrivit endast siffror som lösenord, använd andra tecken."}) # Lösenord är bara siffror
                end
                
            else
                return slim(:"/user/new", locals: {error: "Både lösenord och användarnamn behöver vara minst 4 karaktärer"}) # För kort lösenord
            end
            
        else
            slim(:"/user/new", locals: { error: "Lösenorden stämmer inte överens"})
        end
    else
        slim(:"/login", locals: { error: "Användarnamnet finns redan!"})
    end
end

# Assigns a session if hashed password and user matches DB
# @param username [String]
# @param pwd [String]
post('/login') do

    username = params["user"]
    pwd = params["password"]

    user = User.from_username(username)

    if !user
        return slim(:"/login", locals: {error: "Användaren finns inte!"}) #Fel användarnamn
    elsif User.check_password(user.password_hash, pwd)
        session[:user_id] = user.id
        redirect("/store") 
    else
        return slim(:"/login", locals: {error: "Fel lösenord"}) #Fel lösenord
    end

end

# Creates an item if current user has the permission to do so, 
# @param name [String]
# @param image [String]
# @param price [Integer]
post('/items') do

    if User.from_id(session[:user_id]).rank >= 1

        name = params["name"]
        price = params["price"]

        if params[:image].class == NilClass
            slim(:"/item/new", locals: {feedback: "Använd en fungerande bild"})
        else

            image = "img/#{params[:image][:filename]}"        
            image_url = params[:image][:tempfile]
    
            if name.to_i != 0
    
                slim(:"/item/new", locals: {feedback: "Du angav fel datatyp"})
    
            elsif price.to_i < 0 
    
                slim(:"/item/new", locals: {feedback: "Du angav ett negativt värde"})
    
            elsif price.length == 0 || name.length == 0
    
                slim(:"/item/new", locals: {feedback: "Du angav inte ett pris eller namn"})
    
            else
    
                Item.create(name, price, image, image_url)
                slim(:"/item/new", locals: {feedback: "Item skapades"})
    
            end

        end
        
       
    
    end

end

# Updates user's coins if current user has the permission, validates input aswell
# @param username [String]
# @param coins [Integer]
post('/user/update') do 


    if User.from_id(session[:user_id]).rank >= 1

        username = params["username"]
        coins = params["coins"]

        user = User.select_id(username)
        p user
        if user.empty?

            slim(:"/user/edit", locals: {feedback: "Användaren fanns inte"})

        elsif coins.to_i == 0

            slim(:"/user/edit", locals: {feedback: "Du angav 0 coins eller fel datatyp"})

        else

            User.setcoins(coins, user.first["id"])
            slim(:"/user/edit", locals: {feedback: "Coins för användaren: #{username}, är nu #{coins}"})

        end

    else

        redirect('/store')

    end


end

# Removes item if it exists in DB and User has permission, validates input aswell
# @param item [String]
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

# Queries Users in DB for the input and displays result
# @param query [String]
get('/users') do

    users = User.search(params["query"])
    slim(:"/user/users", locals: {users: users})

end


# Buys the item specified by params, if User has enough coins - aswell as subtracts from User coins
# @param id [Integer]
# @param user_id [Integer]

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

# Creates a trade with the User specified by the User and the User themself using items and trade note from params
# @param fromuserid [Integer]
# @param touserid [Integer]
# @param note [String]
# @param params [String] <= Trade

post('/trades') do

    fromuserid = "U#{current_user.id}"
    touserid = "U#{params[:userid].to_i}"
    note = params[:note]
    trades = []

    
    if check_quality(note) == false
        bad_note = true
        slim(:"/trade/index", locals: {feedback: "Använd även bokstäver i din anteckning", trades: trades})
        
    elsif lengthvalidation(note) == false
        bad_note = true
        slim(:"/trade/index", locals: {feedback: "Använd minst 4 bokstäver i din anteckning", trades: trades})

    else

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

        Trades.create(from_items.to_s, to_items.to_s, note)

        slim(:"/trade/index", locals: {feedback: "Traden skickades", trades: trades})

    end

end

# Accepts Trade if Sender and Reciever still has the items, otherwise declines: validates user owns trade
# @param id [Integer]
# @param reciever [Integer]

post('/trade/:id/accept') do

    tradeid = params[:id]
    reciever = session[:user_id]
    trades = []
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

        slim(:"/trade/index", locals: {feedback: "Bytet fanns ej", trades: trades})
    end

    

end

# Declines trade if user owns trade
# @param id [Integer]
# @param reciever [Integer]
post('/trade/:id/decline') do

    tradeid = params[:id]
    user = current_user.id
    trades = []
    # Ser ifall användaren äger bytet innan det tas bort
    if Trades.delete(tradeid, user) == true
        slim(:"/trade/index", locals: {feedback: "Bytet nekades av dig", trades: trades})
    else
        slim(:"/trade/index", locals: {feedback: "Du äger inte bytet", trades: trades})
    end

end

# Edit Trade note if User owns trade and meets validation requirements
# @param id [Integer]
# @param note [String]
post('/trade/:id/edit') do

    tradeid = params[:id]
    user = current_user.id
    note = params[:note]
    trades = []

    if check_quality(note) == true
        slim(:"/trade/index", locals: {feedback: "Använd även bokstäver i din anteckning", trades: trades})
    end

    if lengthvalidation(note) == false
        slim(:"/trade/index", locals: {feedback: "Använd minst 4 bokstäver i din anteckning", trades: trades})
    end

    p tradeid
    trades = []
    if Trades.update(tradeid, note, user) == true
        slim(:"/trade/index", locals: {feedback: "Bytets anteckning uppdaterades av dig", trades: trades})
    else
        slim(:"/trade/index", locals: {feedback: "Du äger inte bytet", trades: trades})
    end

end
