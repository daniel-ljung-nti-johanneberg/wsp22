def current_user
    User.from_id(session[:user_id])
end


def current_items(user_id)

    # Get Items

    #UserItemRelation = User.from_id(session[:user_id])

    if !user == nil
    end

end

def format_trades(trades)

    trades.map! do |trade|
    
        new_trade = Array.new()
        trade_users = Array.new()

        new_trade << trade["id"]

        new_trade << JSON[trade["sender"]]
        trade_users << new_trade.last.pop[1..-1].to_i

        new_trade << JSON[trade["reciever"]]
        trade_users << new_trade.last.pop[1..-1].to_i

        new_trade[1].map! do |id|

            Item.from_id(id)
                 
        end

        new_trade[2].map! do |id|

            Item.from_id(id)

        end

        new_trade << trade_users

    end

  
end

