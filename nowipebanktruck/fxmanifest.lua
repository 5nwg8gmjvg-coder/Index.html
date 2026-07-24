fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nowipebanktruck'
author 'Custom'
description 'NoWipe bank truck robbery heist - qs-inventory & qs-keys integration'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/truck.lua',
    'client/c4.lua',
    'client/loot.lua'
}

server_scripts {
    'server/main.lua'
}

-- Adjust to your actual resource names if they differ from the
-- ones set in config.lua (Config.Core / InventoryResource / KeysResource).
-- dependencies {
--     'qbx_core',
--     'qs-inventory',
--     'qs-keys'
-- }
