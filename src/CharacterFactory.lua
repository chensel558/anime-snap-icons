--!strict
-- Procedural anime-style characters (no Creator Store rigs). R6 rig (official R6 animations still work) with:
--   * a chibi block head + big anime eyes built from thin parts (render in 3D, in ViewportFrames and from any angle)
--   * a role ARCHETYPE picked from the character's name (swordfighter, ninja, mage, royal, ...) that adds outfit pieces
--     and props, so every character reads as its role from a distance
--   * original colours from a curated palette (hashed per character), fuller hair with fringe/bangs
--   * a rarity AURA: Common none -> Secret rainbow aura + halo + wings (opts.noAura / opts.portrait to skip)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local UIKit = require(ReplicatedStorage.Shared.UIKit)

local Factory = {}

local ANIMS = {
	R6 = {idle = "rbxassetid://180435571", walk = "rbxassetid://180426354", run = "rbxassetid://180426354",
		emotes = {"rbxassetid://128777973", "rbxassetid://129423030", "rbxassetid://182435998", "rbxassetid://128853357"}},
	R15 = {idle = "rbxassetid://507766388", walk = "rbxassetid://507777826", run = "rbxassetid://507767714",
		emotes = {"rbxassetid://507770239", "rbxassetid://507770677", "rbxassetid://507771019"}},
}
Factory.ANIMS = ANIMS

local hx = Color3.fromHex
local SKINS = {hx("FBE3CF"), hx("F5D6B8"), hx("EAC09A"), hx("C98E62"), hx("8E5A3C")}
local HAIR = {"1E1E28", "3A2A22", "6A4228", "F5D84A", "F0A060", "E8E8F0", "FF8AC0", "5AA8FF", "FF6A3A", "8A5AFF", "3AC88A", "C83A4A", "2A4A8A", "B8F0FF"}
local EYES = {"3A7AE0", "C83A3A", "3AA85A", "8A4AE0", "E0A020", "20B8C8", "6A3A20", "E04A9A"}
local CLOTH = {"F2F2F2", "1E2230", "2B5FA8", "C83A3A", "E8C14A", "3AA8A0", "7A4AC8", "E07A3A", "3A3A48", "F07AAA", "4A8A3A", "8A2A3A", "5A7AA8", "D8C8A8"}
local GOLD, METAL, WOOD, DARK = hx("FFD24A"), hx("C8D0DC"), hx("7A4A2A"), hx("1A1A22")

local HEAD = Vector3.new(1.4, 1.3, 1.25)

local function hashN(s: string, salt: number): number
	local h = salt * 7919
	for i = 1, #s do h = (h * 31 + string.byte(s, i)) % 1000003 end
	return h
end
local function pick(list: {any}, s: string, salt: number): any return list[hashN(s, salt) % #list + 1] end

-- ARCHETYPES -----------------------------------------------------------------------------------
local ARCH_WORDS = {
	{"sword", {"sword", "blade", "samurai", "slayer", "pillar", "katana"}},
	{"ninja", {"ninja", "kunai", "scroll", "gourd", "shinobi", "copy", "sensor", "avenger", "illusion", "lavender", "slug"}},
	{"mage", {"mage", "witch", "sorcer", "wizard", "lich", "goddess", "script", "key", "song", "maker", "summoner", "explosion", "rain", "mind", "card", "weather", "angel", "broom"}},
	{"royal", {"princess", "queen", "empress", "heir", "prince", "socialite", "diva", "master", "lady"}},
	{"doctor", {"doctor", "medic", "healer", "nurse", "scholar", "genius", "archaeolog"}},
	{"suit", {"agent", "spy", "clerk", "broker", "handler", "coworker", "receptionist", "prosecutor", "office", "sensei", "brother", "classmate"}},
	{"chef", {"chef", "cook", "barmaid", "shopkeeper"}},
	{"fighter", {"saiyan", "fist", "warrior", "fighter", "vessel", "kick", "iron", "crusader", "hero", "stretch", "boar", "god", "sun", "dancer", "dragon"}},
	{"gunner", {"gunner", "gun", "sniper", "sneezing", "cyborg"}},
	{"beast", {"cat", "fox", "rabbit", "dog", "kitten", "panda", "animal", "boar head", "flying"}},
	{"demon", {"demon", "oni", "cursed", "devil", "biwa", "snake", "masked", "crow", "shadow"}},
}
function Factory.Archetype(def: any): string
	if def.archetype then return def.archetype end
	local n = string.lower(def.name or "")
	for _, a in ipairs(ARCH_WORDS) do
		for _, w in ipairs(a[2]) do if string.find(n, w, 1, true) then return a[1] end end
	end
	return "adventurer"
end

-- parts ------------------------------------------------------------------------------------------
local function newPart(m: Instance, name: string, size: Vector3, color: Color3, cls: string?): BasePart
	local p = Instance.new(cls or "Part") :: BasePart
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = m
	return p
end

-- Attach a decoration to `base` at `offset` (base-local), welded and massless.
local function attach(base: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, o: any?): BasePart
	local opt = o or {}
	local p = newPart(opt.parent or base.Parent, name, size, color, opt.cls)
	if opt.shape then (p :: Part).Shape = opt.shape end
	if opt.mat then p.Material = opt.mat end
	if opt.trans then p.Transparency = opt.trans end
	p.Massless = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = opt.shadow ~= false
	p.CFrame = base.CFrame * offset
	local w = Instance.new("WeldConstraint"); w.Part0 = base; w.Part1 = p; w.Parent = p
	return p
end

local function motor(name: string, p0: BasePart, p1: BasePart, c0: CFrame, c1: CFrame)
	local j = Instance.new("Motor6D")
	j.Name = name
	j.Part0 = p0
	j.Part1 = p1
	j.C0 = c0
	j.C1 = c1
	j.Parent = p0
end

-- Look: all colours for one character (original, hashed; never the source character's canon colours)
local function lookFor(def: any): any
	local id = def.id or def.name or "x"
	local arch = Factory.Archetype(def)
	local main = hx(pick(CLOTH, id, 1))
	local second = hx(pick(CLOTH, id, 2))
	if (second.R + second.G + second.B) - (main.R + main.G + main.B) < 0.15 and second == main then second = hx("F2F2F2") end
	return {
		arch = arch,
		skin = SKINS[hashN(id, 3) % 3 + 1 + (hashN(id, 9) % 7 == 0 and 2 or 0)],
		hair = hx(pick(HAIR, id, 4)),
		eye = hx(pick(EYES, id, 5)),
		main = main,
		second = second,
		trim = (hashN(id, 6) % 2 == 0) and GOLD or hx("F2F2F2"),
		female = def.gender == "F",
	}
end
Factory.Look = lookFor

-- RIG ------------------------------------------------------------------------------------------
local function buildRig(def: any, L: any): Model
	local m = Instance.new("Model")
	local pants = L.main:Lerp(DARK, 0.45)
	local hrp = newPart(m, "HumanoidRootPart", Vector3.new(2, 2, 1), L.main); hrp.Transparency = 1
	local torso = newPart(m, "Torso", Vector3.new(2, 2, 1), L.main)
	local head = newPart(m, "Head", HEAD, L.skin)
	local la = newPart(m, "Left Arm", Vector3.new(1, 2, 1), L.skin)
	local ra = newPart(m, "Right Arm", Vector3.new(1, 2, 1), L.skin)
	local ll = newPart(m, "Left Leg", Vector3.new(1, 2, 1), pants)
	local rl = newPart(m, "Right Leg", Vector3.new(1, 2, 1), pants)
	local R = CFrame.new
	local hy = HEAD.Y / 2
	motor("RootJoint", hrp, torso, R(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), R(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0))
	motor("Neck", torso, head, R(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), R(0, -hy, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0))
	motor("Right Shoulder", torso, ra, R(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), R(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
	motor("Left Shoulder", torso, la, R(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), R(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))
	motor("Right Hip", torso, rl, R(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), R(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
	motor("Left Hip", torso, ll, R(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), R(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))
	-- place parts where joints put them so welded decorations line up
	hrp.CFrame = CFrame.new(0, 3, 0)
	torso.CFrame = hrp.CFrame
	head.CFrame = torso.CFrame * CFrame.new(0, 1 + hy, 0)
	la.CFrame = torso.CFrame * CFrame.new(-1.5, 0, 0)
	ra.CFrame = torso.CFrame * CFrame.new(1.5, 0, 0)
	ll.CFrame = torso.CFrame * CFrame.new(-0.5, -2, 0)
	rl.CFrame = torso.CFrame * CFrame.new(0.5, -2, 0)
	-- sleeves, shoes
	for _, arm in ipairs({la, ra}) do attach(arm, "Sleeve", Vector3.new(1.06, 1.1, 1.06), CFrame.new(0, 0.48, 0), L.main) end
	for _, leg in ipairs({ll, rl}) do attach(leg, "Shoe", Vector3.new(1.08, 0.45, 1.25), CFrame.new(0, -0.8, -0.1), DARK) end
	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R6
	hum.Parent = m
	Instance.new("Animator").Parent = hum
	m.PrimaryPart = hrp
	return m
end

-- FACE (parts, so it shows everywhere) -----------------------------------------------------------
local function addFace(m: Model, L: any, def: any)
	local head = m:FindFirstChild("Head") :: BasePart
	local fz = -HEAD.Z / 2
	local function plate(name: string, size: Vector3, x: number, y: number, depth: number, color: Color3, rot: number?, o: any?)
		local opt = o or {}
		opt.shadow = false
		return attach(head, name, Vector3.new(size.X, size.Y, 0.04), CFrame.new(x, y, fz - depth) * CFrame.Angles(0, 0, math.rad(rot or 0)), color, opt)
	end
	local ex, ey = 0.32, -0.08
	for _, side in ipairs({-1, 1}) do
		local x = ex * side
		plate("EyeWhite", Vector3.new(0.36, 0.44, 0), x, ey, 0.015, Color3.new(1, 1, 1))
		plate("Iris", Vector3.new(0.28, 0.36, 0), x, ey - 0.02, 0.03, L.eye)
		plate("IrisDark", Vector3.new(0.28, 0.14, 0), x, ey + 0.1, 0.035, L.eye:Lerp(DARK, 0.5))
		plate("Pupil", Vector3.new(0.13, 0.19, 0), x, ey - 0.03, 0.045, DARK)
		plate("Shine", Vector3.new(0.09, 0.09, 0), x - 0.06 * side, ey + 0.08, 0.06, Color3.new(1, 1, 1), 0, {mat = Enum.Material.Neon})
		plate("Shine2", Vector3.new(0.05, 0.05, 0), x + 0.07 * side, ey - 0.12, 0.06, Color3.new(1, 1, 1), 0, {mat = Enum.Material.Neon})
		plate("Lash", Vector3.new(0.44, L.female and 0.09 or 0.07, 0), x, ey + 0.23, 0.05, DARK, -8 * side)
		if L.female then plate("LashWing", Vector3.new(0.12, 0.06, 0), x + 0.24 * side, ey + 0.26, 0.05, DARK, -35 * side) end
		plate("Brow", Vector3.new(0.3, 0.06, 0), x, ey + 0.38, 0.03, L.hair:Lerp(DARK, 0.3), (L.arch == "fighter" or L.arch == "demon") and 14 * side or -4 * side)
		if L.female or hashN(def.id or "", 11) % 3 == 0 then plate("Blush", Vector3.new(0.2, 0.07, 0), x + 0.06 * side, ey - 0.3, 0.02, hx("FF8AA8"), 0, {trans = 0.35}) end
	end
	plate("Mouth", Vector3.new(L.female and 0.14 or 0.18, 0.05, 0), 0, -0.45, 0.02, hx("8A2A3A"))
end

-- HAIR -----------------------------------------------------------------------------------------
local MALE_STYLES = {"Spiky", "Messy", "SpikyTall", "Swept", "Short"}
local FEMALE_STYLES = {"Long", "Pony", "Twintails", "Bob", "LongBangs", "Bun"}

local function addHair(m: Model, def: any, L: any)
	local head = m:FindFirstChild("Head") :: BasePart
	local color = L.hair
	local shade = color:Lerp(DARK, 0.18)
	local folder = Instance.new("Model"); folder.Name = "GeneratedHair"; folder.Parent = m
	local HX, HY, HZ = HEAD.X / 2, HEAD.Y / 2, HEAD.Z / 2
	local function piece(size: Vector3, offset: CFrame, o: any?)
		local opt = o or {}
		opt.parent = folder
		return attach(head, "Hair", size, offset, opt.shade and shade or color, opt)
	end
	local function spike(w: number, len: number, offset: CFrame, o: any?)
		local opt = o or {}
		opt.cls = "WedgePart"
		return piece(Vector3.new(w, len, 0.7), offset, opt)
	end
	-- cap: top, back, sides
	piece(Vector3.new(HEAD.X + 0.14, 0.5, HEAD.Z + 0.12), CFrame.new(0, HY - 0.08, 0.02))
	piece(Vector3.new(HEAD.X + 0.14, HEAD.Y * 0.85, 0.24), CFrame.new(0, 0.1, HZ + 0.06), {shade = true})
	for _, s in ipairs({-1, 1}) do piece(Vector3.new(0.16, HEAD.Y * 0.7, HEAD.Z * 0.8), CFrame.new(s * (HX + 0.06), 0.2, 0.12), {shade = true}) end
	-- fringe / bangs: wedges hanging over the forehead (every style gets them; this is what reads "anime")
	local bangN = L.female and 5 or 4
	for i = 1, bangN do
		local x = -HX + 0.1 + (i - 0.5) * (HEAD.X - 0.2) / bangN
		local len = 0.45 + ((i + hashN(def.id or "", 13)) % 3) * 0.12
		spike(0.36, len, CFrame.new(x, HY - 0.22 - len / 2 + 0.2, -HZ - 0.07) * CFrame.Angles(math.pi, 0, math.rad((x / HX) * 12)), {})
	end
	local pool = L.female and FEMALE_STYLES or MALE_STYLES
	local style = (L.arch == "fighter" and not L.female) and "SpikyTall" or pool[hashN(def.id or "", 4) % #pool + 1]
	m:SetAttribute("HairTop", (style == "SpikyTall" and 1.9) or (style == "Spiky" and 1.3) or (style == "Bun" and 0.9) or 0.45)
	if style == "Spiky" or style == "SpikyTall" then
		local len = style == "SpikyTall" and 1.7 or 1.1
		for i = 0, 7 do
			local a = (i / 8) * math.pi * 2
			spike(0.42, len * (0.85 + (i % 2) * 0.25), CFrame.new(math.cos(a) * 0.5, HY + len * 0.3, math.sin(a) * 0.45 + 0.12) * CFrame.Angles(math.sin(a) * 0.75, a, -math.cos(a) * 0.75))
		end
		spike(0.5, len * 1.15, CFrame.new(0, HY + len * 0.42, 0.15))
		for _, s in ipairs({-1, 1}) do spike(0.35, 0.8, CFrame.new(s * (HX + 0.1), -0.05, -0.2) * CFrame.Angles(math.pi, 0, s * 0.2)) end
	elseif style == "Messy" then
		for i = 0, 6 do
			local a = (i / 7) * math.pi * 2
			piece(Vector3.new(0.7, 0.55, 0.7), CFrame.new(math.cos(a) * 0.55, HY + 0.05 + (i % 2) * 0.14, math.sin(a) * 0.5 + 0.1) * CFrame.Angles(0.3, a, 0.2), {shape = Enum.PartType.Ball})
		end
	elseif style == "Swept" then
		for i = 0, 4 do spike(0.45, 1.0, CFrame.new(-0.5 + i * 0.25, HY + 0.15, 0.2 + i * 0.05) * CFrame.Angles(-1.1, 0, -0.4)) end
	elseif style == "Short" then
		piece(Vector3.new(HEAD.X + 0.2, 0.35, HEAD.Z + 0.15), CFrame.new(0, HY + 0.12, 0.02))
	elseif style == "Long" or style == "LongBangs" then
		piece(Vector3.new(HEAD.X + 0.2, 2.6, 0.45), CFrame.new(0, -0.9, HZ + 0.18))
		for _, s in ipairs({-1, 1}) do piece(Vector3.new(0.4, 2.1, 0.9), CFrame.new(s * (HX + 0.12), -0.65, 0.15)) end
		if style == "LongBangs" then for _, s in ipairs({-1, 1}) do spike(0.3, 1.0, CFrame.new(s * (HX - 0.05), -0.35, -HZ - 0.05) * CFrame.Angles(math.pi, 0, 0)) end end
	elseif style == "Pony" then
		piece(Vector3.new(0.65, 0.65, 0.65), CFrame.new(0, HY - 0.05, HZ + 0.3), {shape = Enum.PartType.Ball})
		piece(Vector3.new(0.6, 2.1, 0.6), CFrame.new(0, -0.55, HZ + 0.55) * CFrame.Angles(0.28, 0, 0))
		attach(head, "HairTie", Vector3.new(0.7, 0.18, 0.7), CFrame.new(0, HY - 0.32, HZ + 0.38), L.second, {parent = folder})
	elseif style == "Twintails" then
		for _, s in ipairs({-1, 1}) do
			piece(Vector3.new(0.62, 0.62, 0.62), CFrame.new(s * (HX + 0.15), HY - 0.15, 0.2), {shape = Enum.PartType.Ball})
			piece(Vector3.new(0.55, 2.3, 0.55), CFrame.new(s * (HX + 0.35), -0.85, 0.25) * CFrame.Angles(0, 0, s * -0.18))
			attach(head, "HairTie", Vector3.new(0.3, 0.3, 0.3), CFrame.new(s * (HX + 0.2), HY - 0.15, -0.05), L.second, {parent = folder, shape = Enum.PartType.Ball})
		end
	elseif style == "Bob" then
		piece(Vector3.new(HEAD.X + 0.32, 1.15, HEAD.Z * 0.62), CFrame.new(0, -0.1, HZ * 0.55))
		for _, sd in ipairs({-1, 1}) do piece(Vector3.new(0.3, 1.1, HEAD.Z * 0.7), CFrame.new(sd * (HX + 0.14), -0.12, 0.05)) end
	elseif style == "Bun" then
		piece(Vector3.new(0.85, 0.85, 0.85), CFrame.new(0, HY + 0.35, 0.3), {shape = Enum.PartType.Ball})
		attach(head, "HairStick", Vector3.new(0.08, 1.2, 0.08), CFrame.new(0.15, HY + 0.4, 0.3) * CFrame.Angles(0, 0, 0.9), GOLD, {parent = folder})
	end
end

-- OUTFIT + PROPS per archetype ---------------------------------------------------------------------
local function blade(base: BasePart, cf: CFrame, len: number, guard: Color3, handle: Color3)
	attach(base, "Handle", Vector3.new(0.22, 0.9, 0.22), cf, handle)
	attach(base, "Guard", Vector3.new(0.55, 0.1, 0.4), cf * CFrame.new(0, -0.5, 0), guard, {mat = Enum.Material.Metal})
	attach(base, "Blade", Vector3.new(0.12, len, 0.34), cf * CFrame.new(0, -0.55 - len / 2, 0), METAL, {mat = Enum.Material.Metal})
end

local function addOutfit(m: Model, def: any, L: any, rarityI: number)
	local torso = m:FindFirstChild("Torso") :: BasePart
	local head = m:FindFirstChild("Head") :: BasePart
	local la = m:FindFirstChild("Left Arm") :: BasePart
	local ra = m:FindFirstChild("Right Arm") :: BasePart
	local a = L.arch
	local HY = HEAD.Y / 2
	-- shared: collar + belt (or skirt) give every outfit structure
	attach(torso, "Collar", Vector3.new(1.4, 0.25, 1.1), CFrame.new(0, 0.95, 0), L.second)
	if L.female and a ~= "ninja" and a ~= "fighter" then
		local long = (a == "royal" or a == "mage")
		attach(torso, "Skirt", Vector3.new(2.35, long and 1.9 or 0.95, 1.35), CFrame.new(0, long and -1.75 or -1.3, 0), L.main:Lerp(Color3.new(1, 1, 1), 0.1))
		attach(torso, "SkirtTrim", Vector3.new(2.4, 0.14, 1.4), CFrame.new(0, long and -2.65 or -1.75, 0), L.trim)
	else
		attach(torso, "Belt", Vector3.new(2.05, 0.25, 1.05), CFrame.new(0, -0.85, 0), DARK)
		attach(torso, "Buckle", Vector3.new(0.35, 0.25, 0.08), CFrame.new(0, -0.85, -0.55), L.trim, {mat = Enum.Material.Metal})
	end
	if a == "sword" then
		-- jacket front + sash, blade(s) on the left hip; rarer = more blades
		attach(torso, "Jacket", Vector3.new(0.7, 2.02, 1.06), CFrame.new(-0.67, 0, 0), L.second)
		attach(torso, "Sash", Vector3.new(2.1, 0.3, 1.1), CFrame.new(0, -0.6, 0) * CFrame.Angles(0, 0, 0.18), L.trim)
		blade(torso, CFrame.new(-1.05, -1.0, -0.2) * CFrame.Angles(math.rad(-15), 0, math.rad(-25)), 2.4, GOLD, L.main:Lerp(DARK, 0.5))
		if rarityI >= 4 then blade(torso, CFrame.new(0.3, 0.7, 0.62) * CFrame.Angles(0, 0, math.rad(40)), 2.6, METAL, DARK) end
		if rarityI >= 3 then attach(head, "Bandana", Vector3.new(HEAD.X + 0.18, 0.22, HEAD.Z + 0.18), CFrame.new(0, 0.32, 0), L.main:Lerp(DARK, 0.3)) end
	elseif a == "ninja" then
		attach(head, "Headband", Vector3.new(HEAD.X + 0.16, 0.26, HEAD.Z + 0.16), CFrame.new(0, 0.34, 0), DARK)
		attach(head, "Plate", Vector3.new(0.75, 0.24, 0.06), CFrame.new(0, 0.34, -HEAD.Z / 2 - 0.1), METAL, {mat = Enum.Material.Metal})
		for _, s in ipairs({-1, 1}) do attach(head, "BandTail", Vector3.new(0.18, 0.9, 0.05), CFrame.new(s * 0.2, 0.0, HEAD.Z / 2 + 0.12) * CFrame.Angles(0.3, 0, s * 0.3), DARK) end
		attach(torso, "Scarf", Vector3.new(1.6, 0.42, 1.25), CFrame.new(0, 0.9, 0), L.second)
		attach(torso, "ScarfTail", Vector3.new(0.4, 1.4, 0.1), CFrame.new(0.5, 0.3, 0.6) * CFrame.Angles(0.25, 0, -0.2), L.second)
		attach(torso, "Vest", Vector3.new(2.05, 1.3, 1.08), CFrame.new(0, 0.2, 0), L.main:Lerp(DARK, 0.25))
		for _, arm in ipairs({la, ra}) do attach(arm, "Wrap", Vector3.new(1.06, 0.5, 1.06), CFrame.new(0, -0.65, 0), hx("F2F2F2")) end
		attach(torso, "Pouch", Vector3.new(0.5, 0.45, 0.4), CFrame.new(0.75, -0.95, 0.4), L.main:Lerp(DARK, 0.5))
	elseif a == "mage" then
		attach(torso, "Robe", Vector3.new(2.1, 2.05, 1.1), CFrame.new(0, 0, 0), L.main)
		attach(torso, "RobeTrim", Vector3.new(0.3, 2.06, 1.12), CFrame.new(0, 0, 0), L.trim)
		attach(torso, "Cloak", Vector3.new(2.3, 3.6, 0.15), CFrame.new(0, -0.7, 0.62), L.second)
		local orb = L.eye:Lerp(Color3.new(1, 1, 1), 0.2)
		attach(ra, "Staff", Vector3.new(0.2, 4.6, 0.2), CFrame.new(0, -0.5, -0.65), WOOD)
		attach(ra, "Orb", Vector3.new(0.75, 0.75, 0.75), CFrame.new(0, 1.95, -0.65), orb, {shape = Enum.PartType.Ball, mat = Enum.Material.Neon})
		if L.female then
			attach(head, "HatBrim", Vector3.new(0.12, 2.6, 2.6), CFrame.new(0, HY + 0.15, 0.05) * CFrame.Angles(0, 0, math.rad(90)), L.main:Lerp(DARK, 0.35), {shape = Enum.PartType.Cylinder})
			local hc = L.main:Lerp(DARK, 0.35)
			for k = 0, 3 do
				local w = 1.35 - k * 0.32
				attach(head, "HatCone", Vector3.new(w, 0.5, w), CFrame.new(0, HY + 0.45 + k * 0.42, 0.1 + k * 0.12) * CFrame.Angles(math.rad(-8 - k * 8), 0, 0), hc)
			end
			attach(head, "HatBand", Vector3.new(1.4, 0.16, 1.4), CFrame.new(0, HY + 0.32, 0.1), L.trim)
		else
			attach(head, "Hood", Vector3.new(HEAD.X + 0.4, 0.4, HEAD.Z + 0.4), CFrame.new(0, HY + 0.1, 0.12), L.second)
		end
	elseif a == "royal" then
		attach(head, "Crown", Vector3.new(1.1, 0.3, 1.0), CFrame.new(0, HY + 0.38, 0), GOLD, {mat = Enum.Material.Metal})
		for i = -1, 1 do attach(head, "CrownPoint", Vector3.new(0.18, 0.4, 0.18), CFrame.new(i * 0.38, HY + 0.68, -0.4), GOLD, {mat = Enum.Material.Metal}) end
		attach(head, "Jewel", Vector3.new(0.22, 0.22, 0.08), CFrame.new(0, HY + 0.38, -0.52), L.eye, {mat = Enum.Material.Neon})
		attach(torso, "Cape", Vector3.new(2.4, 3.7, 0.15), CFrame.new(0, -0.75, 0.6), hx("C83A3A"):Lerp(L.second, 0.4))
		attach(torso, "CapeFur", Vector3.new(2.4, 0.4, 1.3), CFrame.new(0, 0.95, 0.1), hx("F8F4EC"))
		attach(torso, "Sash", Vector3.new(0.35, 2.3, 1.12), CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0.5), L.trim)
	elseif a == "doctor" then
		for _, s in ipairs({-1, 1}) do attach(torso, "Coat", Vector3.new(0.85, 2.9, 1.12), CFrame.new(s * 0.6, -0.42, 0), hx("F4F6FA")) end
		for _, arm in ipairs({la, ra}) do attach(arm, "CoatSleeve", Vector3.new(1.08, 1.6, 1.08), CFrame.new(0, 0.2, 0), hx("F4F6FA")) end
		attach(head, "Glasses", Vector3.new(1.0, 0.08, 0.05), CFrame.new(0, -0.0, -HEAD.Z / 2 - 0.09), DARK)
		attach(torso, "Clipboard", Vector3.new(0.7, 0.9, 0.08), CFrame.new(1.5, -0.6, -0.55), WOOD)
	elseif a == "suit" then
		for _, s in ipairs({-1, 1}) do attach(torso, "Lapel", Vector3.new(0.75, 2.02, 1.07), CFrame.new(s * 0.63, 0, 0), L.main:Lerp(DARK, 0.4)) end
		attach(torso, "Shirt", Vector3.new(0.5, 1.6, 1.04), CFrame.new(0, 0.2, 0), hx("F4F6FA"))
		attach(torso, "Tie", Vector3.new(0.22, 1.3, 1.07), CFrame.new(0, 0.25, 0), L.trim == GOLD and hx("C83A3A") or L.second)
		for _, arm in ipairs({la, ra}) do attach(arm, "SuitSleeve", Vector3.new(1.07, 1.75, 1.07), CFrame.new(0, 0.12, 0), L.main:Lerp(DARK, 0.4)) end
	elseif a == "chef" then
		attach(head, "ChefHat", Vector3.new(1.3, 1.0, 1.2), CFrame.new(0, HY + 0.55, 0.05), hx("FAFAFA"))
		attach(head, "ChefPuff", Vector3.new(1.6, 0.8, 1.5), CFrame.new(0, HY + 1.1, 0.05), hx("FAFAFA"), {shape = Enum.PartType.Ball})
		attach(torso, "Apron", Vector3.new(1.6, 2.4, 1.06), CFrame.new(0, -0.3, 0), hx("FAFAFA"))
		attach(torso, "Neckerchief", Vector3.new(1.0, 0.35, 1.12), CFrame.new(0, 0.85, 0), L.second)
	elseif a == "fighter" then
		attach(torso, "Gi", Vector3.new(2.06, 2.02, 1.06), CFrame.new(0, 0, 0), L.main)
		attach(torso, "GiUnder", Vector3.new(0.6, 1.4, 1.07), CFrame.new(0, 0.3, 0), L.second:Lerp(DARK, 0.3))
		attach(torso, "GiBelt", Vector3.new(2.1, 0.3, 1.1), CFrame.new(0, -0.8, 0), L.trim == GOLD and hx("2A4A8A") or DARK)
		for _, arm in ipairs({la, ra}) do attach(arm, "Wristband", Vector3.new(1.1, 0.45, 1.1), CFrame.new(0, -0.7, 0), L.second) end
		if rarityI >= 4 then attach(torso, "ShoulderPad", Vector3.new(2.6, 0.4, 1.2), CFrame.new(0, 0.95, 0), METAL, {mat = Enum.Material.Metal}) end
	elseif a == "gunner" then
		attach(torso, "Jacket", Vector3.new(2.06, 2.02, 1.06), CFrame.new(0, 0, 0), L.main)
		attach(torso, "Strap", Vector3.new(0.3, 2.4, 1.1), CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, -0.55), DARK)
		attach(ra, "Gun", Vector3.new(0.3, 0.55, 1.2), CFrame.new(0, -1.15, -0.4), DARK, {mat = Enum.Material.Metal})
		attach(ra, "Barrel", Vector3.new(0.18, 0.18, 0.8), CFrame.new(0, -1.0, -1.25), METAL, {mat = Enum.Material.Metal})
		attach(head, "Goggles", Vector3.new(HEAD.X + 0.16, 0.25, HEAD.Z + 0.16), CFrame.new(0, 0.48, 0), L.second)
	elseif a == "beast" then
		for _, s in ipairs({-1, 1}) do
			attach(head, "Ear", Vector3.new(0.18, 0.75, 0.55), CFrame.new(s * 0.45, HY + 0.4, 0.05) * CFrame.Angles(0, math.rad(90), math.rad(s * 10)), L.hair, {cls = "WedgePart"})
			attach(head, "EarIn", Vector3.new(0.1, 0.5, 0.35), CFrame.new(s * 0.45, HY + 0.35, -0.02) * CFrame.Angles(0, math.rad(90), math.rad(s * 10)), hx("FFB0C8"), {cls = "WedgePart"})
		end
		attach(torso, "Tail", Vector3.new(0.4, 0.4, 1.8), CFrame.new(0, -0.9, 1.2) * CFrame.Angles(math.rad(-30), 0, 0), L.hair)
		attach(torso, "TailTip", Vector3.new(0.5, 0.5, 0.6), CFrame.new(0, -0.45, 2.0), hx("F8F4EC"), {shape = Enum.PartType.Ball})
		attach(torso, "Bell", Vector3.new(0.35, 0.35, 0.35), CFrame.new(0, 0.8, -0.6), GOLD, {shape = Enum.PartType.Ball, mat = Enum.Material.Metal})
	elseif a == "demon" then
		for _, s in ipairs({-1, 1}) do attach(head, "Horn", Vector3.new(0.22, 0.85, 0.4), CFrame.new(s * 0.45, HY + 0.45, -0.1) * CFrame.Angles(0, 0, math.rad(s * -18)), hx("F8F0E0"), {cls = "WedgePart"}) end
		attach(torso, "Haori", Vector3.new(2.15, 2.05, 1.12), CFrame.new(0, 0, 0), L.main:Lerp(DARK, 0.35))
		attach(torso, "HaoriTrim", Vector3.new(2.2, 0.2, 1.16), CFrame.new(0, -0.95, 0), hx("C83A3A"))
		for _, arm in ipairs({la, ra}) do attach(arm, "Marking", Vector3.new(1.02, 0.12, 1.02), CFrame.new(0, -0.2, 0) * CFrame.Angles(0, 0, 0.4), hx("8A2A3A")) end
	else -- adventurer
		attach(torso, "Jacket", Vector3.new(2.06, 2.02, 1.06), CFrame.new(0, 0, 0), L.main)
		attach(torso, "Shirt", Vector3.new(0.7, 1.7, 1.07), CFrame.new(0, 0.15, 0), L.second)
		attach(torso, "Scarf", Vector3.new(1.5, 0.38, 1.2), CFrame.new(0, 0.9, 0), L.trim == GOLD and hx("C83A3A") or L.second)
		attach(torso, "Bag", Vector3.new(0.6, 0.6, 0.5), CFrame.new(-0.85, -0.9, 0.35), WOOD)
	end
end

-- RARITY AURA ------------------------------------------------------------------------------------
local TEX = {spark = "rbxasset://textures/particles/sparkles_main.dds", fire = "rbxasset://textures/particles/fire_main.dds", smoke = "rbxasset://textures/particles/smoke_main.dds"}
local RAINBOW = ColorSequence.new({ColorSequenceKeypoint.new(0, hx("FF5A5A")), ColorSequenceKeypoint.new(0.25, hx("FFE24A")), ColorSequenceKeypoint.new(0.5, hx("5AFF8A")), ColorSequenceKeypoint.new(0.75, hx("5AC8FF")), ColorSequenceKeypoint.new(1, hx("D05AFF"))})

local function emitter(parent: Instance, o: any): ParticleEmitter
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "Aura"
	pe.Texture = o.tex or TEX.spark
	pe.Color = o.seq or ColorSequence.new(o.color or Color3.new(1, 1, 1))
	pe.LightEmission = o.light or 1
	pe.LightInfluence = 0
	pe.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, o.size or 0.4), NumberSequenceKeypoint.new(1, o.sizeEnd or 0)})
	pe.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, o.t0 or 0.2), NumberSequenceKeypoint.new(1, 1)})
	pe.Lifetime = NumberRange.new(o.life or 0.8, (o.life or 0.8) * 1.6)
	pe.Rate = o.rate or 8
	pe.Speed = NumberRange.new(o.speed or 1.5, (o.speed or 1.5) * 1.8)
	pe.SpreadAngle = o.spread or Vector2.new(180, 180)
	pe.Acceleration = o.accel or Vector3.zero
	pe.RotSpeed = NumberRange.new(-90, 90)
	pe.Rotation = NumberRange.new(0, 360)
	pe.ZOffset = o.z or 0
	if o.shape then pe.Shape = o.shape; pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume end
	pe.Parent = parent
	return pe
end

function Factory.Aura(m: Model, rarity: string)
	local r = Config.Rarities[rarity]
	if not r or r.i <= 1 then return end
	local hrp = m:FindFirstChild("HumanoidRootPart") :: BasePart
	local torso = m:FindFirstChild("Torso") :: BasePart
	local head = m:FindFirstChild("Head") :: BasePart
	if not hrp or not torso then return end
	local col = r.color
	local secret = rarity == "Secret"
	local folder = Instance.new("Folder"); folder.Name = "RarityAura"; folder.Parent = m
	-- 2+: sparkles drifting off the body
	emitter(torso, {color = col, rate = 2 + r.i * 2, size = 0.25 + r.i * 0.05, life = 1, speed = 1, shape = Enum.ParticleEmitterShape.Box})
	if r.i >= 3 then
		-- glowing ring under the feet + soft light
		local ring = attach(hrp, "AuraRing", Vector3.new(0.12, 4.6 + r.i * 0.35, 4.6 + r.i * 0.35), CFrame.new(0, -2.95, 0) * CFrame.Angles(0, 0, math.rad(90)), col,
			{shape = Enum.PartType.Cylinder, mat = Enum.Material.Neon, trans = 0.55, parent = folder, shadow = false})
		ring.Parent = folder
		local pl = Instance.new("PointLight"); pl.Color = col; pl.Range = 6 + r.i * 2; pl.Brightness = 0.6 + r.i * 0.25; pl.Shadows = false; pl.Parent = torso
	end
	if r.i >= 4 then
		-- rising aura wisps around the whole body
		local at = Instance.new("Attachment"); at.Name = "AuraFeet"; at.Position = Vector3.new(0, -2.8, 0); at.Parent = hrp
		emitter(at, {tex = TEX.spark, seq = secret and RAINBOW or nil, color = col, rate = 6 + r.i * 3, size = 0.6, sizeEnd = 0.1, life = 1.2, speed = 3,
			spread = Vector2.new(25, 25), accel = Vector3.new(0, 4, 0), shape = Enum.ParticleEmitterShape.Disc})
		if r.i >= 6 then -- Roblox renders max ~31 Highlights, so only the rarest get an outline
			local hl = Instance.new("Highlight"); hl.Name = "AuraOutline"; hl.FillTransparency = 1; hl.OutlineColor = col; hl.OutlineTransparency = 0.1
			hl.DepthMode = Enum.HighlightDepthMode.Occluded; hl.Parent = m
		end
	end
	if r.i >= 5 then
		-- flame aura (the "power up" look) hugging the body
		emitter(torso, {tex = TEX.fire, seq = secret and RAINBOW or ColorSequence.new(col:Lerp(Color3.new(1, 1, 1), 0.35), col), rate = 18 + (r.i - 5) * 14, size = 2.2 + (r.i - 5) * 0.6, sizeEnd = 0.6,
			life = 0.6, speed = 3.5, light = 0.85, t0 = 0.55, spread = Vector2.new(15, 15), accel = Vector3.new(0, 7, 0), z = -1, shape = Enum.ParticleEmitterShape.Box})
	end
	if r.i >= 6 and head then
		-- floating halo ring + crackling sparks
		local top = (m:GetAttribute("HairTop") :: number?) or 0.6
		local halo = attach(head, "Halo", Vector3.new(0.14, 1.7, 1.7), CFrame.new(0, HEAD.Y / 2 + top + 0.45, 0.15) * CFrame.Angles(0, 0, math.rad(90)), secret and hx("FFF4B0") or col,
			{shape = Enum.PartType.Cylinder, mat = Enum.Material.Neon, trans = 0.15, parent = folder, shadow = false})
		halo.Parent = folder
		emitter(torso, {tex = TEX.spark, color = Color3.new(1, 1, 1), rate = 14, size = 0.5, life = 0.35, speed = 9, shape = Enum.ParticleEmitterShape.Box})
	end
	if secret then
		-- wings + rainbow light
		for _, s in ipairs({-1, 1}) do
			for k = 0, 2 do
				local w = attach(torso, "Wing", Vector3.new(0.12, 3.2 - k * 0.6, 3.4 - k * 0.7), CFrame.new(s * (1.5 + k * 0.9), 0.9 - k * 0.45, 0.95) * CFrame.Angles(0, math.rad(s * 25), math.rad(s * (-25 - k * 20))),
					hx("FFF4B0"):Lerp(hx("9BE8FF"), k * 0.45), {cls = "WedgePart", mat = Enum.Material.Neon, trans = 0.1 + k * 0.12, parent = folder, shadow = false})
				w.Parent = folder
			end
		end
		local pl = torso:FindFirstChildOfClass("PointLight")
		if pl then pl.Color = hx("FFF4B0"); pl.Range = 22; pl.Brightness = 2.5 end
	end
end

-- No fan rigs ship in this place; kept for API compatibility with StandService/SpawnService.
function Factory.HasModel(def: any): boolean
	return false
end

-- opts: {anchored: boolean?, portrait: boolean?, noAura: boolean?}
function Factory.Build(def: any, opts: any?): Model
	local o = opts or {}
	local L = lookFor(def)
	local r = Config.Rarities[def.rarity or "Common"]
	local rarityI = r and r.i or 1
	local m = buildRig(def, L)
	local store = ReplicatedStorage:FindFirstChild("CharacterMeshes")
	local src = store and def.id and store:FindFirstChild(def.id)
	if src and not o.boxy then
		-- AI-generated mesh body on an invisible R6 rig: Humanoid movement, tags and auras keep working.
		for _, p in ipairs(m:GetChildren()) do if p:IsA("BasePart") then p.Transparency = 1 end end
		local body = src:Clone()
		body.Name = "MeshBody"
		local main = body:IsA("BasePart") and body or body:FindFirstChildWhichIsA("BasePart", true)
		if body:IsA("Model") then
			local _, sz = body:GetBoundingBox()
			body:ScaleTo(body:GetScale() * (5.4 / math.max(sz.Y, 0.1)))
		end
		local hrp = m:FindFirstChild("HumanoidRootPart") :: BasePart
		local cf, sz = (body :: any):GetBoundingBox()
		-- feet on the ground (hrp centre is 3 studs above it), centred on the rig, facing -Z like the rig
		body:PivotTo(body:GetPivot() + (hrp.Position - Vector3.new(0, 3 - sz.Y / 2, 0) - cf.Position))
		for _, x in ipairs(body:GetDescendants()) do
			if x:IsA("BasePart") then x.Anchored = false; x.CanCollide = false; x.CanQuery = false; x.CanTouch = false; x.Massless = true end
		end
		for _, x in ipairs(body:GetDescendants()) do
			if x:IsA("BasePart") and x ~= main then local w = Instance.new("WeldConstraint"); w.Part0 = main; w.Part1 = x; w.Parent = x end
		end
		local j = Instance.new("Motor6D"); j.Name = "MeshJoint"; j.Part0 = hrp; j.Part1 = main
		j.C0 = hrp.CFrame:ToObjectSpace(main.CFrame); j.Parent = hrp
		body.Parent = m
		m:SetAttribute("MeshChar", true)
		m:SetAttribute("HairTop", 0.25)
	else
		addFace(m, L, def)
		addHair(m, def, L)
		addOutfit(m, def, L, rarityI)
	end
	if not o.noAura and not o.portrait then Factory.Aura(m, def.rarity or "Common") end
	m.Name = def.id or "Character"
	local hum = m:FindFirstChildOfClass("Humanoid") :: Humanoid
	local hrp = m:FindFirstChild("HumanoidRootPart") :: BasePart
	m.PrimaryPart = hrp
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.BreakJointsOnDeath = false
	hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	hum.RequiresNeck = false
	if not hum:FindFirstChildOfClass("Animator") then Instance.new("Animator").Parent = hum end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanTouch = false
			d.CanQuery = d == hrp
			d.CanCollide = false
			d.Anchored = (o.anchored == true) and d == hrp or false
		end
	end
	if def.scale and def.scale ~= 1 then m:ScaleTo(def.scale) end
	m:SetAttribute("CharId", def.id)
	m:SetAttribute("Rarity", def.rarity)
	m:SetAttribute("Archetype", L.arch)
	return m
end

function Factory.RigType(m: Model): string
	local hum = m:FindFirstChildOfClass("Humanoid")
	return (hum and hum.RigType == Enum.HumanoidRigType.R15) and "R15" or "R6"
end

function Factory.Play(m: Model, kind: string, looped: boolean?): AnimationTrack?
	local hum = m:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not animator then return nil end
	local set = ANIMS[Factory.RigType(m)]
	local id = set[kind]
	if kind == "emote" then id = set.emotes[math.random(1, #set.emotes)] end
	if not id then return nil end
	local a = Instance.new("Animation")
	a.AnimationId = id
	local ok, track = pcall(function() return (animator :: Animator):LoadAnimation(a) end)
	if not ok or not track then return nil end
	track.Looped = looped ~= false and kind ~= "emote"
	track:Play(0.2)
	return track
end

-- Floating name/rarity/mutation tag.
function Factory.Tag(m: Model, def: any, mut: string?, sub: string?, maxDist: number?): BillboardGui
	local hrp = m.PrimaryPart :: BasePart
	local r = Config.Rarities[def.rarity]
	local bb = Instance.new("BillboardGui")
	bb.Name = "CharTag"
	bb.Size = UDim2.fromOffset(300, 110)
	bb.StudsOffset = Vector3.new(0, 4.8 * (def.scale or 1), 0)
	bb.LightInfluence = 0
	bb.MaxDistance = maxDist or 90
	bb.Adornee = hrp
	local name = UIKit.Text(bb, {text = def.name, size = UDim2.fromScale(1, 0.36), font = UIKit.TitleFont, stroke = 3})
	name.Name = "Name"
	local rt = UIKit.Text(bb, {text = def.rarity .. (mut and (" • " .. mut) or ""), size = UDim2.fromScale(1, 0.28), pos = UDim2.fromScale(0, 0.36), color = mut and Config.MutationByName[mut].color or r.color, font = UIKit.TitleFont, stroke = 3})
	rt.Name = "Rarity"
	if def.rarity == "Secret" then
		local g = Instance.new("UIGradient")
		g.Color = RAINBOW
		g.Parent = rt
	end
	local s = UIKit.Text(bb, {text = sub or "", size = UDim2.fromScale(1, 0.3), pos = UDim2.fromScale(0, 0.66), color = hx("7CF06A"), font = UIKit.TitleFont, stroke = 3})
	s.Name = "Sub"
	bb.Parent = hrp
	return bb
end

-- Mutation VFX: sparkles + tinted outline (stacks with the rarity aura).
function Factory.MutationFx(m: Model, mut: string?)
	if not mut then return end
	local md = Config.MutationByName[mut]
	local hrp = m.PrimaryPart
	if not md or not hrp then return end
	emitter(hrp, {color = md.color, rate = 14, size = 0.35, life = 1, speed = 1.5})
	local hl = m:FindFirstChild("AuraOutline") :: Highlight? or Instance.new("Highlight")
	hl.FillTransparency = 0.85
	hl.FillColor = md.color
	hl.OutlineColor = md.color
	hl.OutlineTransparency = 0.3
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = m
end

return Factory
