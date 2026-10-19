-- INDEX --------------------------------------------------------------------------------------
-- Layout (inspired by top simulators): world banner + completion rewards | portrait grid with "!" on unclaimed
-- discoveries + progress bar | selected-character detail pane with per-character rewards. CLAIM ALL in the corner.
local Factory: any = nil
local function charModel(def: any): Model?
	if Factory == nil then
		local m = ReplicatedStorage.Shared:FindFirstChild("CharacterFactory")
		Factory = m and require(m) or false
	end
	if not Factory then return nil end
	local ok, model = pcall(Factory.Build, def, {anchored = true, portrait = true})
	return ok and model or nil
end

local function entryReward(C: any, def: any): any
	local IR = C.Config.Rewards.indexEntry
	local r = C.Config.Rarities[def.rarity]
	return IR and IR[def.rarity] or {{gems = 5 * r.i}}
end

local function variantCount(C: any, idx: any): (number, number)
	local total = 1
	for _ in pairs(C.Config.MutationByName) do total += 1 end
	local have = 0
	if idx then for _ in pairs(idx.mut) do have += 1 end end
	return have, total
end

P.Index = {title = "Anime Index", size = Vector2.new(1420, 860),
	build = function(b, C)
		local UIKit = C.UIKit
		b.world = 1
		local names = {}
		for i = 1, #C.Config.Worlds do table.insert(names, "W" .. i) end
		U.Tabs(b.panel.body, names, function(n) b.world = tonumber(n:sub(2)) :: number; b.sel = nil; b.def.refresh(b, C) end)
		b.claimAll = UIKit.Button(b.panel.body, {text = "CLAIM ALL", style = "green", size = UDim2.fromOffset(300, 56), pos = UDim2.new(1, -306, 0, -2), z = 15, textSize = 34})
		pulse(b.claimAll)
		b.claimAll.Activated:Connect(function() C.Request("ClaimIndexAll") end)
		local Y = 64
		-- left: world banner
		b.banner = Instance.new("Frame"); b.banner.Size = UDim2.new(0, 250, 1, -(Y + 76)); b.banner.Position = UDim2.fromOffset(0, Y); b.banner.ZIndex = 13
		b.banner.BackgroundColor3 = Color3.new(1, 1, 1); UIKit.Corner(b.banner, 14); UIKit.Stroke(b.banner, 5); b.banner.Parent = b.panel.body
		-- centre: grid + progress
		b.grid = UIKit.Scroll(b.panel.body, Vector2.new(168, 200), 12, UDim2.new(1, -(250 + 380 + 28), 1, -(Y + 76 + 56)), UDim2.fromOffset(264, Y))
		local pad = b.grid:FindFirstChildOfClass("UIPadding") :: UIPadding; pad.PaddingTop = UDim.new(0, 14)
		local _, setBar = SK.Bar(b.panel.body, UDim2.new(1, -(250 + 380 + 28), 0, 46), UDim2.new(0, 264, 1, -(76 + 50)), 0, "", "green", 14)
		b.setBar = setBar
		-- right: detail pane + rewards box
		b.detail = Instance.new("Frame"); b.detail.Size = UDim2.new(0, 380, 0, 380); b.detail.Position = UDim2.new(1, -380, 0, Y); b.detail.ZIndex = 13
		b.detail.BackgroundColor3 = Color3.new(1, 1, 1); UIKit.Corner(b.detail, 14); UIKit.Stroke(b.detail, 5); b.detail.Parent = b.panel.body
		b.rewards = Instance.new("Frame"); b.rewards.Size = UDim2.new(0, 380, 1, -(Y + 76 + 396)); b.rewards.Position = UDim2.new(1, -380, 0, Y + 396); b.rewards.ZIndex = 13
		b.rewards.BackgroundColor3 = hx("1E3A2A"); UIKit.Corner(b.rewards, 14); UIKit.Stroke(b.rewards, 4, hx("3AC86A")); b.rewards.Parent = b.panel.body
		-- bottom: total unlocked
		b.total = Instance.new("Frame"); b.total.Size = UDim2.new(1, -394, 0, 64); b.total.Position = UDim2.new(0, 0, 1, -64); b.total.ZIndex = 13
		b.total.BackgroundColor3 = hx("1E2128"); UIKit.Corner(b.total, 14); UIKit.Stroke(b.total, 4); b.total.Parent = b.panel.body
		SK.Art(b.total, "Tree_start", UDim2.fromOffset(76, 76), UDim2.fromOffset(4, -10), {z = 14, rays = false, bob = false})
		b.totalText = UIKit.Text(b.total, {text = "", size = UDim2.new(1, -110, 1, -10), pos = UDim2.fromOffset(96, 5), font = UIKit.TitleFont, z = 14, stroke = 5, textSize = 50})
	end,
	refresh = function(b, C)
		local s, UIKit, F = C.State, C.UIKit, C.Format
		local claimed = s.indexEntry or {}
		local w = C.Config.Worlds[b.world]
		local list = C.Config.Characters.ByWorld[b.world]
		local found = 0
		for _, d in ipairs(list) do if s.index[d.id] then found += 1 end end
		local pct = found / #list * 100
		-- unclaimed across ALL worlds (for Claim All + badge)
		local unclaimedAll, totalFound = 0, 0
		for _, d in ipairs(C.Config.Characters.List) do
			if s.index[d.id] then totalFound += 1; if not claimed[d.id] then unclaimedAll += 1 end end
		end
		UIKit.SetButtonText(b.claimAll, unclaimedAll > 0 and ("CLAIM ALL (%d)"):format(unclaimedAll) or "ALL CLAIMED")
		UIKit.SetStyle(b.claimAll, unclaimedAll > 0 and "green" or "gray")
		b.totalText.Text = ("Unlocked: %d/%d"):format(totalFound, #C.Config.Characters.List)
		-- banner
		U.Clear(b.banner)
		local og = b.banner:FindFirstChildOfClass("UIGradient"); if og then og:Destroy() end
		UIKit.Gradient(b.banner, {w.color:Lerp(Color3.new(1, 1, 1), 0.35), w.color:Lerp(Color3.new(0, 0, 0), 0.25)}, 90)
		UIKit.Text(b.banner, {text = w.name, size = UDim2.new(1, -16, 0, 96), pos = UDim2.fromOffset(8, 12), font = UIKit.TitleFont, z = 14, stroke = 5, textSize = 44})
		UIKit.Text(b.banner, {text = w.show .. " fans", size = UDim2.new(1, -16, 0, 30), pos = UDim2.fromOffset(8, 108), z = 14, stroke = 3, textSize = 24})
		local sc = 0
		for _ in pairs(s.scrolls[tostring(b.world)] or {}) do sc += 1 end
		UIKit.Text(b.banner, {text = ("📜 Scrolls %d/%d"):format(sc, C.Config.Interactables.scrollsPerWorld), size = UDim2.new(1, -16, 0, 30), pos = UDim2.fromOffset(8, 142), z = 14, stroke = 3, textSize = 24})
		-- milestones: claimable rows
		local my = 186
		for i, ms in ipairs(C.Config.Rewards.indexMilestones) do
			local got = s.indexClaims[b.world .. "_" .. i]
			local can = pct >= ms.pct and not got
			local btn = UIKit.Button(b.banner, {text = "", style = got and "dark" or (can and "gold" or "dark"), size = UDim2.new(1, -20, 0, 66), pos = UDim2.fromOffset(10, my), z = 15})
			UIKit.Text(btn, {text = (got and "✔ " or "") .. ms.pct .. "% FOUND", size = UDim2.new(1, -12, 0, 26), pos = UDim2.fromOffset(6, 4), font = UIKit.TitleFont, z = 16, stroke = 3, textSize = 24, color = can and hx("FFFFFF") or hx("FFE27A")})
			UIKit.Text(btn, {text = ("+%d 💎  +%d%% Gen"):format(ms.gems, ms.gen), size = UDim2.new(1, -12, 0, 28), pos = UDim2.fromOffset(6, 32), font = UIKit.TitleFont, z = 16, stroke = 3, textSize = 26, color = hx("7CF06A")})
			if can then pulse(btn) end
			btn.Activated:Connect(function() if can then C.Request("ClaimIndex", {world = b.world, step = i}) end end)
			my += 74
		end
		b.setBar(found / #list, ("%d/%d"):format(found, #list))
		-- grid
		U.Clear(b.grid)
		if not b.sel then
			for _, d in ipairs(list) do if s.index[d.id] and not claimed[d.id] then b.sel = d.id break end end
			if not b.sel then for _, d in ipairs(list) do if s.index[d.id] then b.sel = d.id break end end end
			b.sel = b.sel or list[1].id
		end
		local sorted = table.clone(list)
		table.sort(sorted, function(x, y) return C.Config.Rarities[x.rarity].i < C.Config.Rarities[y.rarity].i end)
		for k, d in ipairs(sorted) do
			local idx = s.index[d.id]
			local rc = C.Config.Rarities[d.rarity].color
			local cell = Instance.new("TextButton"); cell.Text = ""; cell.AutoButtonColor = false; cell.LayoutOrder = k; cell.ZIndex = 14
			cell.BackgroundColor3 = Color3.new(1, 1, 1); UIKit.Corner(cell, 12)
			local st = UIKit.Stroke(cell, d.id == b.sel and 6 or 4, d.id == b.sel and Color3.new(1, 1, 1) or UIKit.Dark)
			UIKit.Gradient(cell, idx and {rc:Lerp(Color3.new(1, 1, 1), 0.55), rc:Lerp(Color3.new(1, 1, 1), 0.1)} or {hx("C8CCD4"), hx("8A8F9A")}, 90)
			local m = charModel(d)
			if m then SK.Portrait(cell, m, {z = 15, fit = 1.1, dark = idx == nil, pos = UDim2.fromOffset(0, 26), size = UDim2.new(1, 0, 1, -30)}) end
			UIKit.Text(cell, {text = idx and d.name or "???", size = UDim2.new(1, -10, 0, 30), pos = UDim2.fromOffset(5, 4), font = UIKit.TitleFont, z = 17, stroke = 4, textSize = 26})
			if idx and not claimed[d.id] then
				local bd = UIKit.Badge(cell); bd.Visible = true; bd.Position = UDim2.new(1, -8, 0, 8)
			end
			UIKit.Bounce(cell)
			cell.Activated:Connect(function() b.sel = d.id; b.def.refresh(b, C) end)
			cell.Parent = b.grid
		end
		-- detail pane
		local d = C.Config.Characters.ById[b.sel]
		local idx = s.index[d.id]
		local r = C.Config.Rarities[d.rarity]
		U.Clear(b.detail)
		local dg = b.detail:FindFirstChildOfClass("UIGradient"); if dg then dg:Destroy() end
		UIKit.Gradient(b.detail, idx and {r.color:Lerp(Color3.new(1, 1, 1), 0.6), r.color:Lerp(Color3.new(1, 1, 1), 0.15)} or {hx("D8DCE4"), hx("9AA0AA")}, 90)
		local stage = Instance.new("Frame"); stage.BackgroundTransparency = 1; stage.Size = UDim2.new(1, 0, 0, 220); stage.ZIndex = 14; stage.Parent = b.detail
		if idx then SK.Art(stage, "StarterBoost", UDim2.fromScale(1, 1), nil, {z = 14, raySpeed = 10 + r.i * 6, bob = false, picScale = 0.001, glow = r.color}) end
		local m = charModel(d)
		if m then SK.Portrait(stage, m, {z = 15, fit = 1.05, dark = idx == nil, spin = idx and 35 or 0}) end
		UIKit.Text(b.detail, {text = idx and d.name or "???", size = UDim2.new(1, -16, 0, 46), pos = UDim2.fromOffset(8, 222), font = UIKit.TitleFont, z = 16, stroke = 5, textSize = 44})
		local pill = Instance.new("Frame"); pill.AnchorPoint = Vector2.new(0.5, 0); pill.Position = UDim2.new(0.5, 0, 0, 268); pill.Size = UDim2.fromOffset(220, 38)
		pill.BackgroundColor3 = UIKit.Dark; pill.ZIndex = 16; UIKit.Corner(pill, 19); pill.Parent = b.detail
		local rt = UIKit.Text(pill, {text = d.rarity, size = UDim2.new(1, -16, 1, -6), pos = UDim2.fromOffset(8, 3), font = UIKit.TitleFont, color = r.color, z = 17, stroke = 2, textSize = 30})
		if d.rarity == "Secret" then local g = Instance.new("UIGradient"); g.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, hx("FF5A5A")), ColorSequenceKeypoint.new(0.5, hx("FFE24A")), ColorSequenceKeypoint.new(1, hx("5AC8FF"))}); g.Parent = rt end
		local base = C.Formulas.CharBase(d.id) * (C.Config.Worlds[d.world].mult or 1)
		UIKit.Text(b.detail, {text = idx and (F.Yen(base) .. "/s") or "Snap it to reveal!", size = UDim2.new(1, -16, 0, 36), pos = UDim2.fromOffset(8, 308), font = UIKit.TitleFont, color = hx("7CF06A"), z = 16, stroke = 4, textSize = 34})
		local have, tot = variantCount(C, idx)
		local vb = Instance.new("Frame"); vb.AnchorPoint = Vector2.new(0.5, 1); vb.Position = UDim2.new(0.5, 0, 1, -6); vb.Size = UDim2.new(1, -40, 0, 40)
		vb.BackgroundColor3 = Color3.new(1, 1, 1); vb.ZIndex = 16; UIKit.Corner(vb, 10); UIKit.Stroke(vb, 3); UIKit.Gradient(vb, UIKit.Colors.green, 90); vb.Parent = b.detail
		UIKit.Text(vb, {text = ("VARIANTS %d/%d"):format(have, tot), size = UDim2.new(1, -12, 1, -6), pos = UDim2.fromOffset(6, 3), font = UIKit.TitleFont, z = 17, stroke = 3, textSize = 30})
		-- rewards box
		U.Clear(b.rewards)
		UIKit.Text(b.rewards, {text = "Rewards:", size = UDim2.new(1, -20, 0, 36), pos = UDim2.fromOffset(14, 8), font = UIKit.TitleFont, align = Enum.TextXAlignment.Left, z = 14, stroke = 3, textSize = 32})
		local scale = 1
		for wk in pairs(s.worlds) do scale = math.max(scale, C.Config.Worlds[tonumber(wk)].mult) end
		local items = RT.List(entryReward(C, d), scale)
		local row = Instance.new("Frame"); row.BackgroundTransparency = 1; row.Size = UDim2.new(1, -20, 0, 112); row.Position = UDim2.fromOffset(10, 46); row.ZIndex = 14; row.Parent = b.rewards
		local rl = Instance.new("UIListLayout"); rl.FillDirection = Enum.FillDirection.Horizontal; rl.HorizontalAlignment = Enum.HorizontalAlignment.Center; rl.Padding = UDim.new(0, 10); rl.Parent = row
		for _, e in ipairs(items) do
			local tile = Instance.new("Frame"); tile.Size = UDim2.fromOffset(108, 112); tile.BackgroundColor3 = hx("2E4A3A"); tile.ZIndex = 14; UIKit.Corner(tile, 10); UIKit.Stroke(tile, 3); tile.Parent = row
			SK.Art(tile, e.icon, UDim2.fromOffset(70, 70), UDim2.fromOffset(19, 4), {z = 15, rays = false, bob = false})
			UIKit.Text(tile, {text = e.text, size = UDim2.new(1, -8, 0, 34), pos = UDim2.fromOffset(4, 74), font = UIKit.TitleFont, z = 16, stroke = 3, textSize = 24})
		end
		local isClaimed = claimed[d.id] == true
		local can = idx ~= nil and not isClaimed
		local btn = UIKit.Button(b.rewards, {text = isClaimed and "CLAIMED!" or (can and "CLAIM!" or "NOT FOUND"), style = can and "green" or "gray", size = UDim2.new(1, -40, 0, 70), pos = UDim2.new(0, 20, 1, -82), z = 15, textSize = 44})
		if can then pulse(btn) end
		btn.Activated:Connect(function() if can then C.Request("ClaimIndexEntry", {id = d.id}) end end)
	end}

