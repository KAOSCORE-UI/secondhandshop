local QBCore = exports['qb-core']:GetCoreObject()
local spawnedPeds = {}

-- Ped Spawning
CreateThread(function()
    for i, pedData in ipairs(Config.NPCs) do
        RequestModel(pedData.model)
        while not HasModelLoaded(pedData.model) do
            Wait(0)
        end

        local ped = CreatePed(0, pedData.model, pedData.coords.x, pedData.coords.y, pedData.coords.z - 1.0, pedData.coords.w, false, false)
        TaskStartScenarioInPlace(ped, pedData.scenario, 0, true)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)

        table.insert(spawnedPeds, ped)

        if pedData.blip and pedData.blip.enabled then
            local blip = AddBlipForCoord(pedData.coords.x, pedData.coords.y, pedData.coords.z)
            SetBlipSprite(blip, pedData.blip.sprite)
            SetBlipColour(blip, pedData.blip.color)
            SetBlipScale(blip, pedData.blip.scale)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(pedData.blip.label)
            EndTextCommandSetBlipName(blip)
        end

        -- Target setup
        local targetOptions = {
            {
                type = "client",
                event = "secondhand:client:openShopMenu",
                icon = "fas fa-shopping-cart",
                label = "View Secondhand Shop",
            },
            {
                type = "client",
                event = "secondhand:client:openSellMenu",
                icon = "fas fa-tag",
                label = "Sell an Item",
            },
            {
                type = "client",
                event = "secondhand:client:claimFunds",
                icon = "fas fa-money-bill-wave",
                label = "Claim Earnings",
            }
        }

        if Config.Target == 'ox' then
            exports.ox_target:addLocalEntity(ped, targetOptions)
        else
            exports['qb-target']:AddTargetEntity(ped, {
                options = targetOptions,
                distance = 2.0
            })
        end
    end
end)

RegisterNetEvent('secondhand:client:openShopMenu', function()
    local PlayerData = QBCore.Functions.GetPlayerData()
    local citizenid = PlayerData.citizenid
    
    QBCore.Functions.TriggerCallback('secondhand:server:getShopItems', function(items)
        if Config.UI == 'custom' then
            SetNuiFocus(true, true)
            SendNUIMessage({
                action = "openShop",
                items = items,
                imagePath = Config.ImagePath,
                playerCitizenId = citizenid
            })
        elseif Config.UI == 'ox' then
            local options = {}
            if #items == 0 then
                table.insert(options, {
                    title = "No items for sale",
                    description = "Check back later!",
                    icon = "fas fa-box-open"
                })
            else
                for _, item in ipairs(items) do
                    local metadata = {}
                    if item.metadata and item.metadata ~= "" then
                        local decoded = json.decode(item.metadata)
                        if decoded then metadata = decoded end
                    end
                    local durability = metadata.quality or metadata.durability
                    local durabilityText = ""
                    if durability then
                        durabilityText = "\nDurability: " .. math.floor(durability) .. "%"
                        if durability <= 15 then durabilityText = durabilityText .. " (⚠️ About to break)" end
                    end
                    
                    local titlePrefix = ""
                    if item.citizenid == citizenid then
                        titlePrefix = "[Yours] "
                    end
                    
                    table.insert(options, {
                        title = titlePrefix .. item.amount .. "x " .. (item.item_name:gsub("^%l", string.upper)), -- Capitalize name
                        description = "Seller: " .. item.seller_name .. "\nPrice: $" .. item.price .. durabilityText,
                        icon = "fas fa-box",
                        onSelect = function()
                            TriggerEvent('secondhand:client:confirmBuy', item, item.citizenid == citizenid)
                        end
                    })
                end
            end

            lib.registerContext({
                id = 'secondhand_shop_menu',
                title = 'Secondhand Shop',
                options = options
            })
            lib.showContext('secondhand_shop_menu')

        else -- qb-menu
            local menu = {
                {
                    header = "Secondhand Shop",
                    isMenuHeader = true
                }
            }
            if #items == 0 then
                table.insert(menu, {
                    header = "No items for sale",
                    txt = "Check back later!"
                })
            else
                for _, item in ipairs(items) do
                    local metadata = {}
                    if item.metadata and item.metadata ~= "" then
                        local decoded = json.decode(item.metadata)
                        if decoded then metadata = decoded end
                    end
                    local durability = metadata.quality or metadata.durability
                    local durabilityText = ""
                    if durability then
                        durabilityText = " | Durability: " .. math.floor(durability) .. "%"
                        if durability <= 15 then durabilityText = durabilityText .. " ⚠️" end
                    end
                    
                    local headerPrefix = ""
                    if item.citizenid == citizenid then
                        headerPrefix = "[Yours] "
                    end
                    
                    table.insert(menu, {
                        header = headerPrefix .. item.amount .. "x " .. (item.item_name:gsub("^%l", string.upper)),
                        txt = "Seller: " .. item.seller_name .. " | Price: $" .. item.price .. durabilityText,
                        params = {
                            event = "secondhand:client:confirmBuy",
                            args = { item = item, isOwner = (item.citizenid == citizenid) }
                        }
                    })
                end
            end
            table.insert(menu, {
                header = "< Close Menu",
                params = {
                    event = "qb-menu:client:closeMenu"
                }
            })
            exports['qb-menu']:openMenu(menu)
        end
    end)
end)

RegisterNetEvent('secondhand:client:confirmBuy', function(data, oxIsOwner)
    local item = data.item or data
    local isOwner = data.isOwner
    if isOwner == nil then isOwner = oxIsOwner end

    if isOwner then
        if Config.UI == 'ox' then
            local alert = lib.alertDialog({
                header = 'Cancel Listing',
                content = ('Are you sure you want to cancel the listing for %dx %s and get your item back?'):format(item.amount, item.item_name),
                centered = true,
                cancel = true
            })
            if alert == 'confirm' then
                TriggerServerEvent('secondhand:server:cancelListing', item.id)
            end
        else
            local menu = {
                {
                    header = "Cancel Listing",
                    isMenuHeader = true
                },
                {
                    header = "Yes, Cancel It",
                    txt = "Retrieve your item",
                    params = {
                        isServer = true,
                        event = "secondhand:server:cancelListing",
                        args = item.id
                    }
                },
                {
                    header = "No, Go Back",
                    params = {
                        event = "secondhand:client:openShopMenu"
                    }
                }
            }
            exports['qb-menu']:openMenu(menu)
        end
        return
    end

    if Config.UI == 'ox' then
        local alert = lib.alertDialog({
            header = 'Confirm Purchase',
            content = ('Are you sure you want to buy %dx %s for $%d?'):format(item.amount, item.item_name, item.price),
            centered = true,
            cancel = true
        })
        if alert == 'confirm' then
            TriggerServerEvent('secondhand:server:buyItem', item.id)
        end
    else
        local menu = {
            {
                header = "Confirm Purchase",
                isMenuHeader = true
            },
            {
                header = "Yes, Buy It",
                txt = "Pay $" .. item.price,
                params = {
                    isServer = true,
                    event = "secondhand:server:buyItem",
                    args = item.id
                }
            },
            {
                header = "No, Go Back",
                params = {
                    event = "secondhand:client:openShopMenu"
                }
            }
        }
        exports['qb-menu']:openMenu(menu)
    end
end)

RegisterNetEvent('secondhand:client:openSellMenu', function()
    QBCore.Functions.TriggerCallback('secondhand:server:getPlayerInventory', function(items)
        if Config.UI == 'ox' then
            local options = {}
            for _, item in ipairs(items) do
                local durability = item.info.quality or item.info.durability
                local desc = "Slot: " .. item.slot
                if durability then
                    desc = desc .. "\nDurability: " .. math.floor(durability) .. "%"
                end
                
                table.insert(options, {
                    title = item.amount .. "x " .. (item.label or item.name),
                    description = desc,
                    icon = "fas fa-box",
                    onSelect = function()
                        TriggerEvent('secondhand:client:sellItemDetails', item)
                    end
                })
            end

            lib.registerContext({
                id = 'secondhand_sell_menu',
                title = 'Select Item to Sell',
                options = options
            })
            lib.showContext('secondhand_sell_menu')
        else
            local menu = {
                {
                    header = "Select Item to Sell",
                    isMenuHeader = true
                }
            }
            for _, item in ipairs(items) do
                local durability = item.info.quality or item.info.durability
                local txt = "Slot: " .. item.slot
                if durability then
                    txt = txt .. " | Durability: " .. math.floor(durability) .. "%"
                end
                
                table.insert(menu, {
                    header = item.amount .. "x " .. (item.label or item.name),
                    txt = txt,
                    params = {
                        event = "secondhand:client:sellItemDetails",
                        args = item
                    }
                })
            end
            table.insert(menu, {
                header = "< Close Menu",
                params = {
                    event = "qb-menu:client:closeMenu"
                }
            })
            exports['qb-menu']:openMenu(menu)
        end
    end)
end)

RegisterNetEvent('secondhand:client:sellItemDetails', function(item)
    if Config.UI == 'ox' then
        local input = lib.inputDialog('Sell ' .. (item.label or item.name), {
            {type = 'number', label = 'Amount to sell', description = 'You have ' .. item.amount, required = true, min = 1, max = item.amount},
            {type = 'number', label = 'Price', description = 'Price for the total amount', required = true, min = 1}
        })

        if not input then return end
        
        local amount = input[1]
        local price = input[2]

        TriggerServerEvent('secondhand:server:listItem', item.slot, amount, price)
    else
        local dialog = exports['qb-input']:ShowInput({
            header = "Sell " .. (item.label or item.name),
            submitText = "List Item",
            inputs = {
                {
                    text = "Amount (Max " .. item.amount .. ")",
                    name = "amount",
                    type = "number",
                    isRequired = true
                },
                {
                    text = "Total Price ($)",
                    name = "price",
                    type = "number",
                    isRequired = true
                }
            }
        })

        if dialog ~= nil then
            local amount = tonumber(dialog.amount)
            local price = tonumber(dialog.price)

            if amount > item.amount then
                QBCore.Functions.Notify("You don't have that many!", "error")
                return
            end

            TriggerServerEvent('secondhand:server:listItem', item.slot, amount, price)
        end
    end
end)

RegisterNetEvent('secondhand:client:claimFunds', function()
    TriggerServerEvent('secondhand:server:claimFunds')
end)

AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    for _, ped in ipairs(spawnedPeds) do
        DeleteEntity(ped)
    end
end)

-- NUI Callbacks
RegisterNUICallback('closeMenu', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('buyItem', function(data, cb)
    SetNuiFocus(false, false)
    if data and data.id then
        TriggerServerEvent('secondhand:server:buyItem', data.id)
    end
    cb('ok')
end)

RegisterNUICallback('cancelListing', function(data, cb)
    SetNuiFocus(false, false)
    if data and data.id then
        TriggerServerEvent('secondhand:server:cancelListing', data.id)
    end
    cb('ok')
end)
