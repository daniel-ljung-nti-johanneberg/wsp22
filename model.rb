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
        @stock = data["id"]

    end

end