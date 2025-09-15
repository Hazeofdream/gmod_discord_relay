require("chttp")

local tmpAvatars = {}
-- for bots
tmpAvatars['0'] = 'https://avatars.cloudflare.steamstatic.com/fef49e7fa7e1997310d705b2a6158ff8dc1cdfeb_full.jpg'
tmpAvatars['relaybot'] = 'https://cdn.discordapp.com/avatars/1416929563056930847/1add2f9946358f5d4a1b4c9af3166bb4.webp'

-- list of prefixes we do NOT want to relay (admin commands, etc.)
local BlockedPrefixes = {
    "!",
    "/",
    "-",
    "."
}

-- helper to check if text starts with a blocked prefix
local function IsBlockedMessage(msg)
    for _, prefix in ipairs(BlockedPrefixes) do
        if string.StartWith(msg, prefix) then
            return true
        end
    end
    return false
end

local IsValid = IsValid
local util_TableToJSON = util.TableToJSON
local util_SteamIDTo64 = util.SteamIDTo64
local http_Fetch = http.Fetch
local coroutine_resume = coroutine.resume
local coroutine_create = coroutine.create
local string_find = string.find

function Discord.send(form)
    if type(form) ~= "table" then
        Error('[Discord] invalid type!')
        return
    end

    -- If the caller passed a short 'bot' id, attempt to use a default avatar for that bot.
    -- e.g. form.bot = '0' or 'relaybot' will use tmpAvatars['0'] unless form.avatar_url is set.
    if form.bot and not form.avatar_url then
        local botDefault = tmpAvatars[tostring(form.bot)]
        if botDefault and botDefault ~= "" then
            form.avatar_url = botDefault
        end
    end

    if not form.username and form.name then
        form.username = form.name
    elseif not form.username and form.username_override then
        form.username = form.username_override
    end

    -- At this point `form` may now contain .username and/or .avatar_url which Discord webhook accepts.
    -- Send JSON body using CHTTP as the existing code did.
    CHTTP({
        ["failed"] = function(msg) print("[Discord] "..msg) end,
        ["method"] = "POST",
        ["url"] = Discord.webhook,
        ["body"] = util_TableToJSON(form),
        ["type"] = "application/json; charset=utf-8"
    })
end

local function getAvatar(id, co)
	http_Fetch( "https://steamcommunity.com/profiles/"..id.."?xml=1", 
	function(body)
		local _, _, url = string_find(body, '<avatarFull>.*.(https://.*)]].*\n.*<vac')
		tmpAvatars[id] = url

		coroutine_resume(co)
	end, 
	function (msg)
		Error("[Discord] error getting avatar ("..msg..")")
	end )
end

local function formMsg( ply, str )
	if IsBlockedMessage(text) then return end
	
	local id = tostring( ply:SteamID64() )

	local co = coroutine_create( function() 
		local form = {
			["username"] = ply:Nick(),
			["content"] = str,
			["avatar_url"] = tmpAvatars[id],
			["allowed_mentions"] = {
				["parse"] = {}
			},
		}
		
		Discord.send(form)
	end )

	if tmpAvatars[id] == nil then 
		getAvatar( id, co )
	else 
		coroutine_resume( co )
	end
end

local function playerConnect( ply )
	local steamid64 = util_SteamIDTo64( ply.networkid )

	if Discord.hideBots and (ply.networkid == "BOT") then return end

	local co = coroutine_create( function()
		local form = {
			["username"] = Discord.hookname,
			["avatar_url"] = "https://cdn.discordapp.com/avatars/1416929563056930847/1add2f9946358f5d4a1b4c9af3166bb4.webp",
			["embeds"] = {{
				["author"] = {
					["name"] = ply.name .. DiscordString.connecting,
					["icon_url"] = tmpAvatars[steamid64],
					["url"] = 'https://steamcommunity.com/profiles/' .. steamid64,
				},
				["color"] = 16763979,
				["footer"] = {
					["text"] = ply.networkid,
				},
			}},
			["allowed_mentions"] = {
				["parse"] = {}
			},
		}

		Discord.send(form)
	end)

	if tmpAvatars[steamid64] == nil then 
		getAvatar( steamid64, co )
	else 
		coroutine_resume( co )
	end
end

local function plyFrstSpawn(ply)
	if IsValid(ply) then
		local steamid = ply:SteamID()
		local steamid64 = util_SteamIDTo64( steamid )

		if Discord.hideBots and ply:IsBot() then return end

		local co = coroutine_create(function()
			local form = {
				["username"] = Discord.hookname,
				["avatar_url"] = "https://cdn.discordapp.com/avatars/1416929563056930847/1add2f9946358f5d4a1b4c9af3166bb4.webp",
				["embeds"] = {{
					["author"] = {
						["name"] = ply:Nick() .. DiscordString.connected,
						["icon_url"] = tmpAvatars[steamid64],
						["url"] = 'https://steamcommunity.com/profiles/' .. steamid64,
					},
					["color"] = 4915018,
					["footer"] = {
						["text"] = steamid,
					},
				}},
				["allowed_mentions"] = {
					["parse"] = {}
				},
			}

			Discord.send(form)
		end)

		if tmpAvatars[steamid64] == nil then 
			getAvatar( steamid64, co )
		else 
			coroutine_resume( co )
		end
	end
end

local function plyDisconnect(ply)
	local steamid64 = util_SteamIDTo64( ply.networkid )

	if Discord.hideBots and (ply.networkid == "BOT") then return end

	local co = coroutine_create(function()
		local form = {
			["username"] = Discord.hookname,
			["avatar_url"] = "https://cdn.discordapp.com/avatars/1416929563056930847/1add2f9946358f5d4a1b4c9af3166bb4.webp",
			["embeds"] = {{
				["author"] = {
					["name"] = ply.name .. DiscordString.disconnected,
					["icon_url"] = tmpAvatars[steamid64],
					["url"] = 'https://steamcommunity.com/profiles/' .. steamid64,
				},
				["description"] = '```' .. ply.reason .. '```',
				["color"] = 16730698,
				["footer"] = {
					["text"] = ply.networkid,
				},
			}},
			["allowed_mentions"] = {
				["parse"] = {}
			},
		}

		Discord.send(form)

		tmpAvatars[steamid64] = nil
	end)

	if tmpAvatars[steamid64] == nil then 
		getAvatar( steamid64, co )
	else 
		coroutine_resume( co )
	end

end

hook.Add("PlayerSay", "!!discord_sendmsg", formMsg)
gameevent.Listen( "player_connect" )
hook.Add("player_connect", "!!discord_plyConnect", playerConnect)
hook.Add("PlayerInitialSpawn", "!!discordPlyFrstSpawn", plyFrstSpawn)
gameevent.Listen( "player_disconnect" )
hook.Add("player_disconnect", "!!discord_onDisconnect", plyDisconnect)

if Discord.srvStarted then
	hook.Add("Initialize", "!!discord_srvStarted", function() 
		local form = {
			["username"] = Discord.hookname,
			["avatar_url"] = "https://cdn.discordapp.com/avatars/1416929563056930847/1add2f9946358f5d4a1b4c9af3166bb4.webp",
			["embeds"] = {{
				["title"] = DiscordString.serverStarted,
				["description"] = DiscordString.currentMapAlt .. game.GetMap(),
				["color"] = 5793266
			}}
		}

		Discord.send(form)
		hook.Remove("Initialize", "!!discord_srvStarted")
	end)
end
if Discord.srvShutdown then
	hook.Add("ShutDown", "!!discord_srvShutdown", function() 
		local form = {
			["username"] = Discord.hookname,
			["avatar_url"] = "https://cdn.discordapp.com/avatars/1416929563056930847/1add2f9946358f5d4a1b4c9af3166bb4.webp",
			["embeds"] = {{
				["title"] = DiscordString.serverShutdown,
				["description"] = '',
				["color"] = 16730698
			}}
		}

		Discord.send(form)
		hook.Remove("Initialize", "!!discord_srvShutdown")
	end)
end
