Config = {}

-- Script Options
Config.UI = 'custom' -- 'qb' for qb-menu/qb-input, 'ox' for ox_lib menus and inputs, 'custom' for the new NUI shop
Config.Target = 'ox' -- 'qb' for qb-target, 'ox' for ox_target
Config.Inventory = 'ox' -- 'qb' for qb-inventory/lj-inventory, 'ox' for ox_inventory

-- Where the UI should pull item images from
Config.ImagePath = Config.Inventory == 'ox' and 'nui://ox_inventory/web/images/' or 'nui://qb-inventory/html/images/'

Config.ShopCurrency = 'bank' -- 'cash' or 'bank' (Where the buyer's money comes from, and where the seller's money goes)
Config.TaxPercent = 5 -- Percentage taken from the sale (0 for no tax)

Config.Webhook = "" -- Paste your discord webhook URL here for logs

Config.NPCs = {
    {
        model = 'a_m_y_business_01', -- Ped model
        coords = vector4(132.86, -1774.52, 29.3, 137.94), -- x, y, z, heading (adjust to your server)
        scenario = 'WORLD_HUMAN_STAND_IMPATIENT', -- Animation scenario
        blip = {
            enabled = true,
            sprite = 59,
            color = 2,
            scale = 0.8,
            label = "Secondhand Market"
        }
    }
}
