# banktruck-heist

A QBox bank truck robbery for `qs-inventory` + `qs-keys`.

## What it does

1. Talk to the contact ped (`Config.Ped`) to start the job. Requires
   `Config.RequiredPolice` on-duty police and respects a server-wide
   cooldown (`Config.Cooldown`, minutes) after each run.
2. A bank truck (`Config.TruckModel`, default `brickade`) spawns at one of
   at least 5 configurable locations (`Config.TruckSpawns`) and patrols a
   route on a loop.
3. Force the truck to stop (block it, shoot the driver, etc.). Once it's
   been stationary for `Config.StopDetection.timeStopped` ms, the guards
   bail out and open fire (`Config.Guards`).
4. Once every guard is dead, plant a C4 charge (`Config.C4.item`, default
   `c4bank`) on the back doors and back off — it arms for
   `Config.C4.armTime` ms then blows the doors off.
5. Loot the truck (`Config.Loot`) for a random cash amount and item rolls,
   each with its own drop chance.
6. Every stage can log to a Discord webhook (`Config.Webhook`).

## Dependencies

- `qbx_core` (or `qb-core` — set `Config.Core`)
- `qs-inventory` (set `Config.InventoryResource` if renamed)
- `qs-keys` / `qs-vehiclekeys` (set `Config.KeysResource` to match — export
  names vary between forks; only used for the optional "give truck keys to
  the looter" bonus, `Config.Loot.giveTruckKeys`)
- Optional: `qb-target` or `ox_target` for proper 3D targeting. Without
  either, the script falls back to a simple `[E]` proximity prompt.

## Installation

1. Drop this folder in your `resources` directory.
2. Add to `server.cfg` **after** your core/inventory/keys resources:
   ```
   ensure banktruck-heist
   ```
3. Add the C4 item to `qs-inventory`'s item list (`items.lua` or your
   shared items file), e.g.:
   ```lua
   ['c4bank'] = {
       name = 'c4bank',
       label = 'C4 Charge',
       weight = 2000,
       type = 'item',
       image = 'c4bank.png',
       unique = false,
       useable = false,
       description = 'Breaches armored doors.'
   },
   ```
   This resource removes the item directly via the `qs-inventory`
   `RemoveItem` export when a charge is planted — no item-use handler is
   registered on it, so `useable` above can stay `false`.
4. Make sure the loot items in `Config.Loot.items` (`goldbar`,
   `markedbills`, `diamond`, `rolex`, `weapon_pistol` by default) exist in
   your inventory's item list, or change the list to items you already
   have.
5. Open `config.lua` and set:
   - `Config.Ped.coords` — where the contact ped stands.
   - `Config.TruckSpawns` — at least 5 `{ spawn, route }` entries. Use
     your server's coords command in-game to grab real `vector4`/`vector3`
     values and replace the placeholders (current ones are approximate).
   - `Config.RequiredPolice`, `Config.Cooldown`.
   - `Config.Webhook.url` — your Discord webhook URL.
   - `Config.KeysResource` / `Config.InventoryResource` if your resource
     names differ from the defaults.

## Notes on the C4 back doors

`Config.C4.doorIndices` auto-detects the last 2 doors on the vehicle model
if left `nil`. If the doors that blow off don't look right for your
truck model, set it explicitly, e.g. `Config.C4.doorIndices = {2, 3}`.

## Known limitation

The player who talks to the ped becomes the "director" for that run — their
client is responsible for the truck's AI. If that player disconnects while
the heist is active, the run is cancelled and the cooldown starts, even if
teammates are mid-fight or about to loot. For most crews this is a non-issue,
but keep it in mind if you plan runs with players who have unstable
connections.

## Notes on qs-keys / qs-vehiclekeys

Export names differ between forks of this resource. This script calls:
```lua
exports[Config.KeysResource]:GiveKeys(plate, model)
```
client-side on the looter after a successful loot. If your installed
version uses a different export name/signature, edit the call in
`client/loot.lua` (`banktruck:client:giveKeys` handler) to match — the
rest of the heist works independently of this bonus feature.
