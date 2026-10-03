local QBCore = exports['qb-core']:GetCoreObject()

local function SendDiscordLog(src, title, message, color)
    if Config.Webhook == "" or Config.Webhook == nil then return end

    local discord = "Not Found"
    local license = "Not Found"

    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        if string.find(id, "discord:") then
            discord = "<@" .. string.gsub(id, "discord:", "") .. "> (" .. id .. ")"
        elseif string.find(id, "license:") then
            license = id
        end
    end

    local embed = {
        {
            ["color"] = color,
            ["title"] = "**" .. title .. "**",
            ["description"] = message .. "\n\n**Server ID:** " .. src .. "\n**Discord:** " .. discord .. "\n**License:** " .. license,
            ["footer"] = {
                ["text"] = "Secondhand Shop Logs",
            },
        }
    }
    PerformHttpRequest(Config.Webhook, function(err, text, headers) end, 'POST', json.encode({username = "Shop Logs", embeds = embed}), { ['Content-Type'] = 'application/json' })
end

-- Callbacks
QBCore.Functions.CreateCallback('secondhand:server:getShopItems', function(source, cb)
    MySQL.Async.fetchAll('SELECT * FROM secondhand_shop ORDER BY created_at DESC', {}, function(result)
        cb(result)
    end)
end)

QBCore.Functions.CreateCallback('secondhand:server:getPlayerInventory', function(source, cb)
    local items = {}
    if Config.Inventory == 'ox' then
        local inv = exports.ox_inventory:GetInventoryItems(source)
        for slot, item in pairs(inv) do
            if item and item.name then
                table.insert(items, {
                    name = item.name,
                    label = item.label,
                    amount = item.count or item.amount,
                    info = item.metadata or {},
                    slot = slot
                })
            end
        end
    else
        local Player = QBCore.Functions.GetPlayer(source)
        for slot, item in pairs(Player.PlayerData.items) do
            if item and item.name then
                table.insert(items, {
                    name = item.name,
                    label = item.label,
                    amount = item.amount,
                    info = item.info or {},
                    slot = slot
                })
            end
        end
    end
    cb(items)
end)

QBCore.Functions.CreateCallback('secondhand:server:getPendingFunds', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(0) end

    MySQL.Async.fetchScalar('SELECT SUM(amount) FROM secondhand_funds WHERE citizenid = ?', {Player.PlayerData.citizenid}, function(result)
        cb(tonumber(result) or 0)
    end)
end)

-- Events
RegisterNetEvent('secondhand:server:listItem', function(slot, amount, price)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    amount = tonumber(amount)
    price = tonumber(price)

    if not amount or amount <= 0 or not price or price <= 0 then
        SendDiscordLog(src, "Exploit Attempt", "Player **" .. GetPlayerName(src) .. "** (" .. Player.PlayerData.citizenid .. ") tried to list an item with amount or price <= 0.\nAmount: " .. tostring(amount) .. "\nPrice: " .. tostring(price), 16711680)
        TriggerClientEvent('QBCore:Notify', src, "Invalid amount or price", "error")
        return
    end

    local itemData = nil
    if Config.Inventory == 'ox' then
        itemData = exports.ox_inventory:GetSlot(src, slot)
    else
        itemData = Player.Functions.GetItemBySlot(slot)
    end

    if not itemData then
        SendDiscordLog(src, "Exploit Attempt", "Player **" .. GetPlayerName(src) .. "** (" .. Player.PlayerData.citizenid .. ") tried to list an item from an empty slot (Slot: " .. tostring(slot) .. ").", 16711680)
        TriggerClientEvent('QBCore:Notify', src, "Item not found", "error")
        return
    end

    local itemAmount = itemData.count or itemData.amount
    if itemAmount < amount then
        SendDiscordLog(src, "Exploit Attempt", "Player **" .. GetPlayerName(src) .. "** (" .. Player.PlayerData.citizenid .. ") tried to list more items than they have.\nItem: " .. itemData.name .. "\nAttempted Amount: " .. amount .. "\nActual Amount: " .. itemAmount, 16711680)
        TriggerClientEvent('QBCore:Notify', src, "You don't have that many", "error")
        return
    end

    local itemName = itemData.name
    local itemLabel = itemData.label
    local itemMetadata = itemData.metadata or itemData.info or {}

    -- Remove item
    local removed = false
    if Config.Inventory == 'ox' then
        removed = exports.ox_inventory:RemoveItem(src, itemName, amount, itemMetadata, slot)
    else
        removed = Player.Functions.RemoveItem(itemName, amount, slot)
    end

    if removed then
        MySQL.Async.insert('INSERT INTO secondhand_shop (citizenid, seller_name, item_name, amount, price, metadata) VALUES (?, ?, ?, ?, ?, ?)', {
            Player.PlayerData.citizenid,
            Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname,
            itemName,
            amount,
            price,
            json.encode(itemMetadata)
        }, function(id)
            SendDiscordLog(src, "Item Listed", "Player **" .. GetPlayerName(src) .. "** (" .. Player.PlayerData.citizenid .. ") listed **" .. amount .. "x " .. itemLabel .. "** for **$" .. price .. "**.", 65280)
            TriggerClientEvent('QBCore:Notify', src, "Successfully listed " .. amount .. "x " .. itemLabel .. " for $" .. price, "success")
        end)
    else
        TriggerClientEvent('QBCore:Notify', src, "Failed to remove item", "error")
    end
end)

RegisterNetEvent('secondhand:server:buyItem', function(shopId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    MySQL.Async.fetchAll('SELECT * FROM secondhand_shop WHERE id = ?', {shopId}, function(result)
        if result and result[1] then
            local shopItem = result[1]
            local price = tonumber(shopItem.price)

            -- Check if player is the seller
            if shopItem.citizenid == Player.PlayerData.citizenid then
                TriggerClientEvent('QBCore:Notify', src, "You cannot buy your own item", "error")
                return
            end

            -- Check money
            if Player.PlayerData.money[Config.ShopCurrency] >= price then
                -- Remove money
                Player.Functions.RemoveMoney(Config.ShopCurrency, price, "Secondhand Shop Purchase")

                -- Delete from shop before giving item to prevent exploits
                MySQL.Async.execute('DELETE FROM secondhand_shop WHERE id = ?', {shopId}, function(rowsChanged)
                    if rowsChanged > 0 then
                        -- Give item
                        local metadata = json.decode(shopItem.metadata) or {}
                        if Config.Inventory == 'ox' then
                            exports.ox_inventory:AddItem(src, shopItem.item_name, shopItem.amount, metadata)
                        else
                            Player.Functions.AddItem(shopItem.item_name, shopItem.amount, nil, metadata)
                        end
                        SendDiscordLog(src, "Item Purchased", "Player **" .. GetPlayerName(src) .. "** (" .. Player.PlayerData.citizenid .. ") bought **" .. shopItem.amount .. "x " .. shopItem.item_name .. "** for **$" .. price .. "** from **" .. shopItem.seller_name .. "**.", 3447003)
                        TriggerClientEvent('QBCore:Notify', src, "You bought an item for $" .. price, "success")

                        -- Pay Seller
                        local payAmount = price
                        if Config.TaxPercent > 0 then
                            payAmount = math.floor(price * (1 - (Config.TaxPercent / 100)))
                        end

                        local Seller = QBCore.Functions.GetPlayerByCitizenId(shopItem.citizenid)
                        if Seller then
                            -- Online
                            Seller.Functions.AddMoney(Config.ShopCurrency, payAmount, "Secondhand Shop Sale")
                            TriggerClientEvent('QBCore:Notify', Seller.PlayerData.source, "Someone bought your " .. shopItem.item_name .. "! You received $" .. payAmount, "success")
                        else
                            -- Offline, save to funds
                            MySQL.Async.insert('INSERT INTO secondhand_funds (citizenid, amount) VALUES (?, ?)', {
                                shopItem.citizenid,
                                payAmount
                            })
                        end
                    else
                        -- Delete failed (maybe someone bought it at the exact same time)
                        Player.Functions.AddMoney(Config.ShopCurrency, price, "Secondhand Shop Refund")
                        TriggerClientEvent('QBCore:Notify', src, "Item is no longer available", "error")
                    end
                end)
            else
                TriggerClientEvent('QBCore:Notify', src, "Not enough " .. Config.ShopCurrency, "error")
            end
        else
            SendDiscordLog(src, "Exploit Attempt", "Player **" .. GetPlayerName(src) .. "** (" .. Player.PlayerData.citizenid .. ") tried to buy a non-existent item (ID: " .. tostring(shopId) .. ").", 16711680)
            TriggerClientEvent('QBCore:Notify', src, "Item not found", "error")
        end
    end)
end)

RegisterNetEvent('secondhand:server:cancelListing', function(shopId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    MySQL.Async.fetchAll('SELECT * FROM secondhand_shop WHERE id = ?', {shopId}, function(result)
        if result and result[1] then
            local shopItem = result[1]

            -- Check if player is the seller
            if shopItem.citizenid ~= Player.PlayerData.citizenid then
                SendDiscordLog(src, "Exploit Attempt", "Player **" .. GetPlayerName(src) .. "** (" .. Player.PlayerData.citizenid .. ") tried to cancel someone else's item (ID: " .. tostring(shopId) .. ").", 16711680)
                TriggerClientEvent('QBCore:Notify', src, "You cannot cancel someone else's listing", "error")
                return
            end

            MySQL.Async.execute('DELETE FROM secondhand_shop WHERE id = ?', {shopId}, function(rowsChanged)
                if rowsChanged > 0 then
                    local metadata = json.decode(shopItem.metadata) or {}
                    if Config.Inventory == 'ox' then
                        exports.ox_inventory:AddItem(src, shopItem.item_name, shopItem.amount, metadata)
                    else
                        Player.Functions.AddItem(shopItem.item_name, shopItem.amount, nil, metadata)
                    end
                    SendDiscordLog(src, "Listing Cancelled", "Player **" .. GetPlayerName(src) .. "** (" .. Player.PlayerData.citizenid .. ") cancelled their listing for **" .. shopItem.amount .. "x " .. shopItem.item_name .. "**.", 16753920)
                    TriggerClientEvent('QBCore:Notify', src, "You cancelled your listing and received your item back", "success")
                else
                    TriggerClientEvent('QBCore:Notify', src, "Item is no longer available", "error")
                end
            end)
        else
            TriggerClientEvent('QBCore:Notify', src, "Item not found", "error")
        end
    end)
end)
RegisterNetEvent('secondhand:server:claimFunds', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid

    MySQL.Async.fetchAll('SELECT id, amount FROM secondhand_funds WHERE citizenid = ?', {citizenid}, function(result)
        local totalAmount = 0
        local idsToDelete = {}

        if result and #result > 0 then
            for _, row in ipairs(result) do
                totalAmount = totalAmount + row.amount
                table.insert(idsToDelete, row.id)
            end

            if totalAmount > 0 then
                Player.Functions.AddMoney(Config.ShopCurrency, totalAmount, "Secondhand Shop Claim")
                SendDiscordLog(src, "Funds Claimed", "Player **" .. GetPlayerName(src) .. "** (" .. Player.PlayerData.citizenid .. ") claimed **$" .. totalAmount .. "** from offline sales.", 3447003)
                TriggerClientEvent('QBCore:Notify', src, "You claimed $" .. totalAmount .. " from past sales!", "success")

                -- Delete claimed funds
                local placeholders = {}
                for i = 1, #idsToDelete do
                    table.insert(placeholders, "?")
                end
                
                if #placeholders > 0 then
                    local query = 'DELETE FROM secondhand_funds WHERE id IN (' .. table.concat(placeholders, ",") .. ')'
                    MySQL.Async.execute(query, idsToDelete)
                end
            else
                TriggerClientEvent('QBCore:Notify', src, "You have no funds to claim", "error")
            end
        else
            TriggerClientEvent('QBCore:Notify', src, "You have no funds to claim", "error")
        end
    end)
end)
