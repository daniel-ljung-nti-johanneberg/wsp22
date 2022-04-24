def db
    _db = SQLite3::Database.new("data/database.db")
    _db.results_as_hash = true
    _db
end


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

    def self.from_username(username)

        result = db.execute("SELECT * FROM User WHERE username = ?", [username]).first

        #result && new(result) # <== Control flow operator

        if result == nil
            return nil
        else
            return new(result)
        end

    end

    def self.search(query)


        users = db.execute("SELECT * FROM User WHERE username LIKE '%#{query}%'")

        users.map do |user|

            new user

        end


    end

    
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


end



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

end

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

    def self.list(userid)

        trades = db.execute("SELECT * FROM Trades WHERE reciever LIKE '%U#{userid}%'")
        new_trades = format_trades(trades)

    end

    def self.select(tradeid)

        trade = db.execute("SELECT * FROM Trades WHERE id = ?", tradeid).first

    end

    def self.exchange(trade, tradeid, reciever)

        match1 = true
        match2 = true
        trade = Trades.select(tradeid)
        new_trade = Array.new()
        trade_users = Array.new()

        if trade == nil
            return
        end
    
        new_trade << JSON[trade["sender"]]
        trade_users << new_trade.last.pop[1..-1].to_i
    
        new_trade << JSON[trade["reciever"]]
        trade_users << new_trade.last.pop[1..-1].to_i
    
        if reciever != trade_users[1]
    
            return

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
    
        end
    
        db.execute("DELETE FROM Trades WHERE id = ?", tradeid)

    end

    def self.create(from_items, to_items)

        db.execute('INSERT into Trades (sender, reciever) VALUES (?, ?)', from_items, to_items)

    end


end