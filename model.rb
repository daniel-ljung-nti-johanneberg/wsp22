
    def db
        _db = SQLite3::Database.new("data/database.db")
        _db.results_as_hash = true
        _db
    end


    # Superclass, database objects    
    class BaseModel

        attr_reader :id

        def self.table; end

        def initialize(data)

            @id = data['id']


        end

        def self.from_id(id)

            result = db.execute("SELECT * FROM #{self.table} WHERE id = ?", id).first
            
            result && new(result) # Om result finns skapa ett nytt objekt

        end


    end

    # Userclass, For user
    class User < BaseModel

        attr_reader :username, :coins, :rank, :password_hash

        def self.table

            'User'

        end

        def initialize(data)

            super data

            @username = data['username']
            @coins = data['coins']
            @rank = data['rank']
            @password_hash = data['password']

        end
        
        # Returns a User object, from username
        # @param username [String]
        # @return [User] User object
        def self.from_username(username)

            result = db.execute("SELECT * FROM User WHERE username = ?", [username]).first

            result && new(result)

        end

        # Returns id from username
        def self.select_id(username)

            return db.execute('SELECT id FROM User WHERE username=?',username)

        end

        # Creates a user in DB, using user and hashed password
        # @param user [String]
        # @param pwd_digest [String]
        def self.create(user, pwd_digest)

            db.execute('INSERT INTO User (username, password) VALUES(?, ?)', user, pwd_digest)

        end

        # Set coins of user to specified
        # @param userid [Integer]
        # @param coins [Integer]
        def self.setcoins(coins, userid)

            db.execute("UPDATE User SET coins = ? WHERE id = ? ",coins,userid)

        end

        # Creates a hashed password from password
        # @param pwd [String]
        def self.create_password(pwd)

            return BCrypt::Password.create(pwd)

        end

        # Checks if hashed password matches password using BCrypt
        # @param password_hash [String]
        # @param pwd [String]
        def self.check_password(password_hash, pwd)

            return BCrypt::Password.new(password_hash) == pwd

        end


        # Queries/searches DB for query
        # @param query [String]
        def self.search(query)


            users = db.execute("SELECT * FROM User WHERE username LIKE '%#{query}%'")

            users.map do |user|

                new user

            end


        end

        # Load items of userid, gets items from DB
        # @param userid [Integer]
        def self.LoadItems(userid)


            # If userid unspecified, load all store items

            if !userid
                return db.execute("SELECT * FROM Items")
            end

            their_items = Array.new

            relationtable = db.execute("SELECT * FROM UserItemRelation")

            relationtable.each do |element|

                if element["userid"] == userid
        
                    their_items << element["itemid"] 
        
                end

            end

            return their_items
    
        end

        # Puts Item and User in a relationtable
        # @param user_id [Integer]
        # @param item_id [Integer]
        def self.recieve_item(user_id, item_id)

            db.execute("INSERT into UserItemRelation (userid, itemid) VALUES (?, ?)", user_id, item_id)

        end


    end


    # Item class, template for Items
    class Item < BaseModel

        attr_reader :name, :price, :image_url, :id, :stock

        def self.table

            'Items'

        end
    
        def initialize(data)
            super data
            @image_url = data["image_url"]
            @price = data["price"]
            @name = data["name"]
            @id = data["id"]

        end

        # Creates item from parameters, puts it in DB
        # @param name [String]
        # @param price [Integer]
        # @param image [Image data]
        # @param image_url [String]
        def self.create(name, price, image, image_url)

            db.execute("INSERT into Items (name, price, image_url) VALUES (?, ?, ?)", name, price, image)
            p image
            p image_url
            File.open(("public/" + image), "wb") do |f|
                f.write(image_url.read)
            end

        end

        # Returns item_name
        # @param item_name [String]
        def self.item_name(item_name)

            db.execute("SELECT name FROM Items WHERE name = ?", item_name)

        end

        # Returns item_id from item_name
        # @param item_name [String]
        def self.item_id(item_name)

            item_id = db.execute("SELECT id FROM Items WHERE name = ?", item_name)
            if !item_id.empty?
                return item_id.first["id"]
            else 
                return []
            end

        end

        # Deletes Item from all places in DB
        # @param item_name [String]
        # @param item_id [Integer]
        def self.delete(item_name, item_id)

            db.execute("DELETE FROM Items WHERE name = ?", item_name)
            db.execute("DELETE FROM UserItemRelation WHERE itemid = ?", item_id)

            db.execute("DELETE FROM Trades WHERE reciever LIKE '%[#{item_id},%'")
            db.execute("DELETE FROM Trades WHERE reciever LIKE '% #{item_id},%'")
            db.execute("DELETE FROM Trades WHERE reciever LIKE '%#{item_id},%'")

            db.execute("DELETE FROM Trades WHERE sender LIKE '%[#{item_id},%'")
            db.execute("DELETE FROM Trades WHERE sender LIKE '% #{item_id},%'")
            db.execute("DELETE FROM Trades WHERE sender LIKE '%#{item_id},%'")

        end

        # Returns price of Item
        # @param price [Integer]
        def self.price(item_id)

            db.execute("SELECT price FROM Items WHERE id = ?", [item_id]).first["price"]

        end

    end

    # Trade class, template for Trades
    class Trades < BaseModel


        def self.table

            'Trades'

        end
    
        def initialize(data)
        
            super data
            @id = data["id"]
            @sender = data["price"]
            @reciever = data["name"]

        end

        # Returns a list of all trades using userid
        # @param userid [Integer]
        def self.list(userid)

            trades = db.execute("SELECT * FROM Trades WHERE reciever LIKE '%U#{userid}%'")
            new_trades = format_trades(trades)

        end

        # Selects a trade using tradeid and returns the trade
        # @param tradeid [Integer]
        def self.select(tradeid)

            trade = db.execute("SELECT * FROM Trades WHERE id = ?", tradeid).first

        end

        # Exchanges items of two users, if they still have the items as is in Trade
        # @param trade [Array]
        # @param tradeid [Integer]
        # @param reciever [Integer]
        def self.exchange(trade, tradeid, reciever)

            match1 = true
            match2 = true
            trade = Trades.select(tradeid)
            new_trade = Array.new()
            trade_users = Array.new()
        
            new_trade << JSON[trade["sender"]]
            trade_users << new_trade.last.pop[1..-1].to_i
        
            new_trade << JSON[trade["reciever"]]
            trade_users << new_trade.last.pop[1..-1].to_i
        
            # Ser om reciever, (inloggad användare) äger bytet eller ej (Checkar även med db)
            if reciever != trade_users[1]
        
                return false

            end
        
            for itemid in new_trade.first
            
                rowid = db.execute("SELECT rowid, * FROM UserItemRelation WHERE itemid = ? AND userid = ?", itemid, trade_users[0])
                if rowid.length < 1
                    match1 = false
                end
        
            end
        
            for itemid in new_trade.last
        
                rowid = db.execute("SELECT rowid, * FROM UserItemRelation WHERE itemid = ? AND userid = ?", itemid, reciever)
                if rowid.length < 1
                    match2 = false
                end
        
            end
        
            if match1 && match2 == true
        
                for itemid in new_trade.first
                    rowid = db.execute("SELECT rowid, * FROM UserItemRelation WHERE itemid = ? AND userid = ?", itemid, trade_users[0])
                    new_rowid = rowid.first
                    db.execute("DELETE FROM UserItemRelation WHERE rowid = ?", new_rowid["rowid"])
        
                end
        
                for itemid in new_trade.last
                    rowid = db.execute("SELECT rowid, * FROM UserItemRelation WHERE itemid = ? AND userid = ?", itemid, reciever)
                    new_rowid = rowid.first
                    db.execute("DELETE FROM UserItemRelation WHERE rowid = ?", new_rowid["rowid"])
                end
        
                for itemid in new_trade[0]
        
                    db.execute('INSERT into UserItemRelation (userid, itemid) VALUES (?, ?)', reciever, itemid)
        
                end
        
                for itemid in new_trade[1]
        
                    db.execute('INSERT into UserItemRelation (userid, itemid) VALUES (?, ?)', trade_users[0], itemid)
        
                end

                return true
        
            end

            return false
            

        end

        # Creates a trade with from_items and to_items + a note
        # @param from_items [Array]
        # @param to_items [Array]
        # @param note [String]
        def self.create(from_items, to_items, note)

            db.execute('INSERT into Trades (sender, reciever, note) VALUES (?, ?, ?)', from_items, to_items, note)

        end

        # Updates a trade, (the note), checks if user owns the trade
        # @param tradeid [Integer]
        # @param note [String]
        # @param user [Integer]
        def self.update(tradeid, note, user)

            trade = select(tradeid)
            new_trade = Array.new()
            trade_users = Array.new

            new_trade << JSON[trade["sender"]]
            trade_users << new_trade.last.pop[1..-1].to_i
        
            new_trade << JSON[trade["reciever"]]
            trade_users << new_trade.last.pop[1..-1].to_i

            sender = trade_users[0]
            reciever = trade_users[1]

            # Ser om nuvarande användare äger resursen, kan vara sender/reciever som byter note
            if user == reciever || sender 

                db.execute("UPDATE Trades SET note = ? WHERE id = ? ", note, tradeid)
                return true

            else
                return false
            end

        end

        
        # Deletes a trade if the reciever matches the reciever in DB
        # @param tradeid [Integer]
        # @param user [Integer]
        def self.delete(tradeid, user)
            
            trade = select(tradeid)
            new_trade = Array.new()
            trade_users = Array.new

            new_trade << JSON[trade["sender"]]
            trade_users << new_trade.last.pop[1..-1].to_i
        
            new_trade << JSON[trade["reciever"]]
            trade_users << new_trade.last.pop[1..-1].to_i

            reciever = trade_users[1]

            if reciever == user
                db.execute("DELETE FROM Trades WHERE id = ?", tradeid)
                return true
            else
                return false #äger ej tradeid
            end

        end


    end
