# Secondhand Shop

A robust, player-to-player marketplace script for FiveM allowing players to list, sell, and buy items from one another securely. 

## Features
- **Multiple UI Options:** Choose between a sleek Custom HTML NUI, `ox_lib` context menus, or `qb-menu`.
- **Dynamic Marketplace:** Players can set their own prices for items and list them.
- **Offline Earnings:** If an item sells while the seller is offline, the funds are held securely and can be claimed anytime via the "Claim Earnings" menu.
- **Item Condition Support:** Supports displaying item deterioration/durability. If an item is about to break, it visually warns buyers to prevent scamming.
- **Cancel Listings:** Sellers can cancel their listings at any time and receive their items back securely.
- **Exploit Prevention:** Backend checks prevent duplication, buying your own items, cancelling other players' items, or invalid prices.
- **Discord Logging:** Built-in webhook logging for sales, listings, cancelled listings, and exploit attempts.
- **Tax System:** Configurable tax percentage on successful sales.
- **Framework Support:** Supports both `qb-core` and `ox_inventory`, as well as `qb-target` and `ox_target`.

## Dependencies
- [qb-core](https://github.com/qbcore-framework/qb-core)
- **Target System:** [qb-target](https://github.com/qbcore-framework/qb-target) OR [ox_target](https://github.com/overextended/ox_target)
- **Inventory System:** [qb-inventory](https://github.com/qbcore-framework/qb-inventory) / lj-inventory OR [ox_inventory](https://github.com/overextended/ox_inventory)
- **Menus (if not using Custom UI):** [qb-menu](https://github.com/qbcore-framework/qb-menu) + [qb-input](https://github.com/qbcore-framework/qb-input) OR [ox_lib](https://github.com/overextended/ox_lib)

## Installation
1. Download or clone this repository into your `resources` folder.
2. Ensure you have the required dependencies running.
3. Import the database tables by running the provided `install.sql` file in your database.
4. Configure the script to your liking in `config.lua`.
5. Ensure the resource in your `server.cfg`:
```cfg
ensure secondhandshop
```

## Configuration (`config.lua`)
- `Config.UI`: Select the UI you want (`'custom'`, `'ox'`, or `'qb'`).
- `Config.Target`: Select the target script you are using (`'ox'` or `'qb'`).
- `Config.Inventory`: Select your inventory (`'ox'` or `'qb'`).
- `Config.ShopCurrency`: Choose between `'bank'` or `'cash'` for transactions.
- `Config.TaxPercent`: The percentage of the sale taken out (e.g., `5` means a 5% tax).
- `Config.Webhook`: Your Discord Webhook URL for logs.
- `Config.NPCs`: Define the coordinates, ped models, and blip settings for the secondhand shops around the map.

## Database Installation (`install.sql`)
Make sure to run the `install.sql` file to create the `secondhand_shop` and `secondhand_funds` tables. If you don't have it, create the tables manually with these columns:
- **`secondhand_shop`**: id, citizenid, seller_name, item_name, amount, price, metadata, created_at.
- **`secondhand_funds`**: id, citizenid, amount, created_at.
