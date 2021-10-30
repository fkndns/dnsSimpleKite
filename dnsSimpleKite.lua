require "DamageLib"
require "2DGeometry"
require "MapPositionGOS"
require "PremiumPrediction"


local EnemyHeroes = {}
local AllyHeroes = {}
local EnemySpawnPos = nil
local AllySpawnPos = nil

--[[ AutoUpdate deactivated until proper rank.
do
    
    local Version = 1.0
    
    local Files = {
        Lua = {
            Path = SCRIPT_PATH,
            Name = "dnsMages.lua",
            Url = "https://raw.githubusercontent.com/fkndns/dnsMages/main/dnsMages.lua"
       },
        Version = {
            Path = SCRIPT_PATH,
            Name = "dnsActivator.version",
            Url = "https://raw.githubusercontent.com/fkndns/dnsMages/main/dnsMages.version"    -- check if Raw Adress correct pls.. after you have create the version file on Github
        }
    }
    
    local function AutoUpdate()
        
        local function DownloadFile(url, path, fileName)
            DownloadFileAsync(url, path .. fileName, function() end)
            while not FileExist(path .. fileName) do end
        end
        
        local function ReadFile(path, fileName)
            local file = io.open(path .. fileName, "r")
            local result = file:read()
            file:close()
            return result
        end
        
        DownloadFile(Files.Version.Url, Files.Version.Path, Files.Version.Name)
        local textPos = myHero.pos:To2D()
        local NewVersion = tonumber(ReadFile(Files.Version.Path, Files.Version.Name))
        if NewVersion > Version then
            DownloadFile(Files.Lua.Url, Files.Lua.Path, Files.Lua.Name)
            print("New dnsMarksmen Version. Press 2x F6")     -- <-- you can change the massage for users here !!!!
        else
            print(Files.Version.Name .. ": No Updates Found")   --  <-- here too
        end
    
    end
    
    AutoUpdate()

end 
--]]

local ItemHotKey = {[ITEM_1] = HK_ITEM_1, [ITEM_2] = HK_ITEM_2,[ITEM_3] = HK_ITEM_3, [ITEM_4] = HK_ITEM_4, [ITEM_5] = HK_ITEM_5, [ITEM_6] = HK_ITEM_6,}

local InterruptSpells = {
    ["Caitlyn"] = {"CaitlynAceintheHole"},
    ["FiddleSticks"] = {"Crowstorm"},
    ["FiddleSticks"] = {"DrainChannel"},
    ["Galio"] = {"GalioIdolOfDurand"},
    ["Janna"] = {"ReapTheWhirlwind"},
    ["Karthus"] = {"KarthusFallenOne"},
    ["Katarina"] = {"KatarinaR"},
    ["Lucian"] = {"LucianR"},
    ["Malzahar"] = {"AlZaharNetherGrasp"},
    ["MasterYi"] = {"Meditate"},
    ["MissFortune"] = {"MissFortuneBulletTime"},
    ["Nunu"] = {"NunuR"},
    ["Pantheon"] = {"PantheonRJump"},
    ["Pantheon"] = {"PantheonRFall"},
    ["Shen"] = {"ShenStandUnited"},
    ["TwistedFate"] = {"Destiny"},
    ["Urgot"] = {"UrgotSwap2"},
    ["Velkoz"] = {"VelkozR"},
    ["Warwick"] = {"WarwickR"},
    ["Xerath"] = {"XerathLocusOfPower2"}
}

local function GetInventorySlotItem(itemID)
    assert(type(itemID) == "number", "GetInventorySlotItem: wrong argument types (<number> expected)")
    for _, j in pairs({ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6}) do
        if myHero:GetItemData(j).itemID == itemID and myHero:GetSpellData(j).currentCd == 0 then return j end
    end
    return nil
end

local function IsNearEnemyTurret(pos, distance)
    --PrintChat("Checking Turrets")
    local turrets = _G.SDK.ObjectManager:GetTurrets(GetDistance(pos) + 1000)
    for i = 1, #turrets do
        local turret = turrets[i]
        if turret and GetDistance(turret.pos, pos) <= distance+915 and turret.team == 300-myHero.team then
            --PrintChat("turret")
            return turret
        end
    end
end

local function IsUnderEnemyTurret(pos)
    --PrintChat("Checking Turrets")
    local turrets = _G.SDK.ObjectManager:GetTurrets(GetDistance(pos) + 1000)
    for i = 1, #turrets do
        local turret = turrets[i]
        if turret and GetDistance(turret.pos, pos) <= 915 and turret.team == 300-myHero.team then
            --PrintChat("turret")
            return turret
        end
    end
end

function GetDifference(a,b)
    local Sa = a^2
    local Sb = b^2
    local Sdif = (a-b)^2
    return math.sqrt(Sdif)
end

function GetDistanceSqr(Pos1, Pos2)
    local Pos2 = Pos2 or myHero.pos
    local dx = Pos1.x - Pos2.x
    local dz = (Pos1.z or Pos1.y) - (Pos2.z or Pos2.y)
    return dx^2 + dz^2
end

function DrawTextOnHero(hero, text, color)
    local pos2D = hero.pos:To2D()
    local posX = pos2D.x - 50
    local posY = pos2D.y
    Draw.Text(text, 28, posX + 50, posY - 15, color)
end

function GetDistance(Pos1, Pos2)
    return math.sqrt(GetDistanceSqr(Pos1, Pos2))
end

function IsImmobile(unit)
    local MaxDuration = 0
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 then
            local BuffType = buff.type
            if BuffType == 5 or BuffType == 12 or BuffType == 22 or BuffType == 23 or BuffType == 25 or BuffType == 30 or BuffType == 35 or buff.name == "recall" then
                local BuffDuration = buff.duration
                if BuffDuration > MaxDuration then
                    MaxDuration = BuffDuration
                end
            end
        end
    end
    return MaxDuration
end

function IsCleanse(unit)
    local MaxDuration = 0
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 then
            local BuffType = buff.type
            if BuffType == 5 or BuffType == 8 or BuffType == 10 or BuffType == 12 or BuffType == 22 or BuffType == 23 or BuffType == 25 or BuffType == 32 then
                local BuffDuration = buff.duration
                if BuffDuration > MaxDuration then
                    MaxDuration = BuffDuration
                end
            end
        end
    end
    return MaxDuration
end

function IsChainable(unit)
    local MaxDuration = 0
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 then
            local BuffType = buff.type
            if BuffType == 5 or BuffType == 8 or BuffType == 10 or BuffType == 12 or BuffType == 22 or BuffType == 23 or BuffType == 25 or BuffType == 32 or BuffType == 11 then
                local BuffDuration = buff.duration
                if BuffDuration > MaxDuration then
                    MaxDuration = BuffDuration
                end
            end
        end
    end
    return MaxDuration
end

function GetEnemyHeroes()
    for i = 1, Game.HeroCount() do
        local Hero = Game.Hero(i)
        if Hero.isEnemy then
            table.insert(EnemyHeroes, Hero)
            PrintChat(Hero.name)
        end
    end
    --PrintChat("Got Enemy Heroes")
end

function GetEnemyBase()
    for i = 1, Game.ObjectCount() do
        local object = Game.Object(i)
        
        if not object.isAlly and object.type == Obj_AI_SpawnPoint then 
            EnemySpawnPos = object
            break
        end
    end
end

function GetAllyBase()
    for i = 1, Game.ObjectCount() do
        local object = Game.Object(i)
        
        if object.isAlly and object.type == Obj_AI_SpawnPoint then 
            AllySpawnPos = object
            break
        end
    end
end

function GetAllyHeroes()
    for i = 1, Game.HeroCount() do
        local Hero = Game.Hero(i)
        if Hero.isAlly and Hero.charName ~= myHero.charName then
            table.insert(AllyHeroes, Hero)
            PrintChat(Hero.name)
        end
    end
    --PrintChat("Got Enemy Heroes")
end

function GetBuffStart(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then 
            return buff.startTime
        end
    end
    return nil
end

function GetBuffExpire(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then 
            return buff.expireTime
        end
    end
    return nil
end

function GetBuffDuration(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then 
            return buff.duration
        end
    end
    return 0
end

function GetBuffStacks(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then 
            return buff.count
        end
    end
    return 0
end

local function GetWaypoints(unit) -- get unit's waypoints
    local waypoints = {}
    local pathData = unit.pathing
    table.insert(waypoints, unit.pos)
    local PathStart = pathData.pathIndex
    local PathEnd = pathData.pathCount
    if PathStart and PathEnd and PathStart >= 0 and PathEnd <= 20 and pathData.hasMovePath then
        for i = pathData.pathIndex, pathData.pathCount do
            table.insert(waypoints, unit:GetPath(i))
        end
    end
    return waypoints
end

local function GetUnitPositionNext(unit)
    local waypoints = GetWaypoints(unit)
    if #waypoints == 1 then
        return nil -- we have only 1 waypoint which means that unit is not moving, return his position
    end
    return waypoints[2] -- all segments have been checked, so the final result is the last waypoint
end

local function GetUnitPositionAfterTime(unit, time)
    local waypoints = GetWaypoints(unit)
    if #waypoints == 1 then
        return unit.pos -- we have only 1 waypoint which means that unit is not moving, return his position
    end
    local max = unit.ms * time -- calculate arrival distance
    for i = 1, #waypoints - 1 do
        local a, b = waypoints[i], waypoints[i + 1]
        local dist = GetDistance(a, b)
        if dist >= max then
            return Vector(a):Extended(b, dist) -- distance of segment is bigger or equal to maximum distance, so the result is point A extended by point B over calculated distance
        end
        max = max - dist -- reduce maximum distance and check next segments
    end
    return waypoints[#waypoints] -- all segments have been checked, so the final result is the last waypoint
end

function GetTarget(range)
    if _G.SDK then
        return _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_MAGICAL);
    else
        return _G.GOS:GetTarget(range,"AD")
    end
end

function CalcRDmg(unit)
    local Damage = 0
    local Distance = GetDistance(myHero.pos, unit.pos)
    local MathDist = math.floor(math.floor(Distance)/100)   
    local level = myHero:GetSpellData(_R).level
    local BaseQ = ({25, 35, 45})[level] + 0.15 * myHero.bonusDamage
    local QMissHeal = ({25, 30, 35})[level] / 100 * (unit.maxHealth - unit.health)
    local dist = myHero.pos:DistanceTo(unit.pos)
    if Distance < 100 then
        Damage = BaseQ + QMissHeal
    elseif Distance >= 1500 then
        Damage = BaseQ * 10 + QMissHeal     
    else
        Damage = ((((MathDist * 6) + 10) / 100) * BaseQ) + BaseQ + QMissHeal
    end
    return CalcPhysicalDamage(myHero, unit, Damage)
end

function GotBuff(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        --PrintChat(buff.name)
        if buff.name == buffname and buff.count > 0 then 
            return buff.count
        end
    end
    return 0
end

function BuffActive(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then 
            return true
        end
    end
    return false
end

function IsReady(spell)
    return myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and myHero:GetSpellData(spell).mana <= myHero.mana and Game.CanUseSpell(spell) == 0
end

function Mode()
    if _G.SDK then
        if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
            return "Combo"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] or Orbwalker.Key.Harass:Value() then
            return "Harass"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] or Orbwalker.Key.Clear:Value() then
            return "LaneClear"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] or Orbwalker.Key.LastHit:Value() then
            return "LastHit"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
            return "Flee"
        end
    else
        return GOS.GetMode()
    end
end

function GetItemSlot(unit, id)
    for i = ITEM_1, ITEM_7 do
        if unit:GetItemData(i).itemID == id then
            return i
        end
    end
    return 0
end

function IsFacing(unit)
    local V = Vector((unit.pos - myHero.pos))
    local D = Vector(unit.dir)
    local Angle = 180 - math.deg(math.acos(V*D/(V:Len()*D:Len())))
    if math.abs(Angle) < 80 then 
        return true  
    end
    return false
end

function IsMyHeroFacing(unit)
    local V = Vector((myHero.pos - unit.pos))
    local D = Vector(myHero.dir)
    local Angle = 180 - math.deg(math.acos(V*D/(V:Len()*D:Len())))
    if math.abs(Angle) < 80 then 
        return true  
    end
    return false
end

function SetMovement(bool)
    if _G.PremiumOrbwalker then
        _G.PremiumOrbwalker:SetAttack(bool)
        _G.PremiumOrbwalker:SetMovement(bool)       
    elseif _G.SDK then
        _G.SDK.Orbwalker:SetMovement(bool)
        _G.SDK.Orbwalker:SetAttack(bool)
    end
end


local function CheckHPPred(unit, SpellSpeed)
     local speed = SpellSpeed
     local range = myHero.pos:DistanceTo(unit.pos)
     local time = range / speed
     if _G.SDK and _G.SDK.Orbwalker then
         return _G.SDK.HealthPrediction:GetPrediction(unit, time)
     elseif _G.PremiumOrbwalker then
         return _G.PremiumOrbwalker:GetHealthPrediction(unit, time)
    end
end

local function IsValid(unit)
    if (unit and unit.valid and unit.isTargetable and unit.alive and unit.visible and unit.networkID and unit.pathing and unit.health > 0) then
        return true;
    end
    return false;
end

local function ClosestPointOnLineSegment(p, p1, p2)
    local px = p.x
    local pz = p.z
    local ax = p1.x
    local az = p1.z
    local bx = p2.x
    local bz = p2.z
    local bxax = bx - ax
    local bzaz = bz - az
    local t = ((px - ax) * bxax + (pz - az) * bzaz) / (bxax * bxax + bzaz * bzaz)
    if (t < 0) then
        return p1, false
    end
    if (t > 1) then
        return p2, false
    end
    return {x = ax + t * bxax, z = az + t * bzaz}, true
end

local function ValidTarget(unit, range)
    if (unit and unit.valid and unit.isTargetable and unit.alive and unit.visible and unit.networkID and unit.pathing and unit.health > 0) then
        if range then
            if GetDistance(unit.pos) <= range then
                return true;
            end
        else
            return true
        end
    end
    return false;
end

local function GetEnemyCount(range, pos)
    local count = 0
    for i, hero in pairs(EnemyHeroes) do
    local Range = range * range
        if GetDistanceSqr(pos, hero.pos) < Range and IsValid(hero) then
        count = count + 1
        end
    end
    return count
end

local function GetEnemyCountLinear(range, pos)
    local count = 0
    for i, enemy in pairs(EnemyHeroes) do
        local enemyLine = ClosestPointOnLineSegment(enemy.pos, pos, myHero.pos)
        if GetDistance(enemy.pos, enemyLine) <= range and ValidTarget(enemy) then
            count = count + 1
        end
    end
    return count
end
 
local function GetAllyCount(range, pos)
    local count = 0
    for i, hero in pairs(AllyHeroes) do
    local Range = range * range
        if GetDistanceSqr(pos, hero.pos) < Range and IsValid(hero) then
        count = count + 1
        end
    end
    return count
end

local function GetMinionCount(checkrange, range, pos)
    local minions = _G.SDK.ObjectManager:GetEnemyMinions(checkrange)
    local count = 0
    for i = 1, #minions do 
        local minion = minions[i]
        local Range = range * range
        if GetDistanceSqr(pos, minion.pos) < Range and IsValid(minion) then
            count = count + 1
        end
    end
    return count
end

local function GetMinionCountLinear(checkrange, range, pos)
    local minions = _G.SDK.ObjectManager:GetEnemyMinions(checkrange)
    local count = 0 
    for i = 1, #minions do
        local minion = minions[i]
        local spellLine = ClosestPointOnLineSegment(minion.pos, myHero.pos, pos)
        if GetDistance(minion.pos, spellLine) <= range and ValidTarget(minion) then
            count = count + 1
        end
    end
    return count
end

local function dnsTargetSelector(unit, range)
    local fullDamUnit = (unit.totalDamage + unit.ap * 0.7)
    local healthPercentUnit = (unit.health / unit.maxHealth)
    local unitStrength = fullDamUnit / healthPercentUnit
    local dtarget = nil
    if dtarget ~= nil then
        local fullDamdtarget = (dtarget.totalDamage + dtarget.ap * 0.7) 
        local healthPercentdtarget = (dtarget.health / dtarget.maxHealth) 
        local dtargetStrength = fullDamdtarget / healthPercentdtarget
    end
    if ValidTarget(unit, range) then
        --PrintChat("target")
        if dtarget == nil or unitStrength > dtargetStrength then
            dtarget = unit
            PrintChat(dtarget.charName)
        end
    end
    return dtarget
end

function GetTurretShot(unit)
    local turrets = _G.SDK.ObjectManager:GetTurrets(GetDistance(unit.pos) + 1000)
    for i = 1, #turrets do
        local turret = turrets[i]
        if turret and turret.activeSpell.valid and turret.activeSpell.target == unit.handle and not turret.activeSpell.isStopped and turret.team == 300-myHero.team then
            --PrintChat("turret shot")
            return true
        else
            return false
        end
    end
end

local function CastSpellMM(spell,pos,range,delay)
local castSpell = {state = 0, tick = GetTickCount(), casting = GetTickCount() - 1000, mouse = mousePos}
local range = range or math.huge
local delay = delay or 250
local ticker = GetTickCount()
    if castSpell.state == 0 and GetDistance(myHero.pos,pos) < range and ticker - castSpell.casting > delay + Game.Latency() then
        castSpell.state = 1
        castSpell.mouse = mousePos
        castSpell.tick = ticker
    end
    if castSpell.state == 1 then
        if ticker - castSpell.tick < Game.Latency() then
            local castPosMM = pos:ToMM()
            Control.SetCursorPos(castPosMM.x,castPosMM.y)
            Control.KeyDown(spell)
            Control.KeyUp(spell)
            castSpell.casting = ticker + delay
            DelayAction(function()
                if castSpell.state == 1 then
                    Control.SetCursorPos(castSpell.mouse)
                    castSpell.state = 0
                end
            end,Game.Latency()/1000)
        end
        if ticker - castSpell.casting > Game.Latency() then
            Control.SetCursorPos(castSpell.mouse)
            castSpell.state = 0
        end
    end
end

local function CastSpellMM(spell,pos,range,delay)
local castSpell = {state = 0, tick = GetTickCount(), casting = GetTickCount() - 1000, mouse = mousePos}
local range = range or math.huge
local delay = delay or 250
local ticker = GetTickCount()
    if castSpell.state == 0 and GetDistance(myHero.pos,pos) < range and ticker - castSpell.casting > delay + Game.Latency() then
        castSpell.state = 1
        castSpell.mouse = mousePos
        castSpell.tick = ticker
    end
    if castSpell.state == 1 then
        if ticker - castSpell.tick < Game.Latency() then
            local castPosMM = pos:ToMM()
            Control.SetCursorPos(castPosMM.x,castPosMM.y)
            Control.KeyDown(spell)
            Control.KeyUp(spell)
            castSpell.casting = ticker + delay
            DelayAction(function()
                if castSpell.state == 1 then
                    Control.SetCursorPos(castSpell.mouse)
                    castSpell.state = 0
                end
            end,Game.Latency()/1000)
        end
        if ticker - castSpell.casting > Game.Latency() then
            Control.SetCursorPos(castSpell.mouse)
            castSpell.state = 0
        end
    end
end

local function HitChanceConvert(menVal)
    if menVal == 1 then
        return 0
    elseif menVal == 2 then 
        return 0.25
    elseif menVal == 3 then
        return 0.5
    elseif menVal == 4 then
        return 0.75
    elseif menVal == 5 then
        return 1
    end
end

function dnsCast(spell, pos, prediction, hitchance)
    local hitchance = hitchance or 0.1
    if pos == nil and prediction == nil then
        Control.KeyDown(spell)
        Control.KeyUp(spell)
    elseif prediction == nil then
        if pos:ToScreen().onScreen then
            _G.Control.CastSpell(spell, pos)
        else
            CastSpellMM(spell, pos)
        end
    else
        if prediction.type == "circular" then
            local pred = _G.PremiumPrediction:GetPrediction(myHero, pos, prediction)
            if pred.CastPos and pred.HitChance >= hitchance and GetDistance(pred.CastPos, myHero.pos) <= prediction.range then
                if pred.CastPos:ToScreen().onScreen then
                    _G.Control.CastSpell(spell, pred.CastPos)
                else
                    CastSpellMM(spell, pred.CastPos)
                end
            end
        elseif prediction.type == "linear" then
            local pred = _G.PremiumPrediction:GetPrediction(myHero, pos, prediction)
            if pred.CastPos and pred.HitChance >= hitchance and GetDistance(pred.CastPos, myHero.pos) <= prediction.range then
                if pred.CastPos:ToScreen().onScreen then
                    _G.Control.CastSpell(spell, pred.CastPos)
                else
                    local CastSpot = myHero.pos:Extended(pred.CastPos, 800)
                    _G.Control.CastSpell(spell, CastSpot)
                end
            end
        elseif prediction.type == "conic" then
            local pred = _G.PremiumPrediction:GetPrediction(myHero, pos, prediction)
            if pred.CastPos and pred.HitChance >= hitchance and GetDistance(pred.CastPos, myHero.pos) <= prediction.range then
                if pred.CastPos:ToScreen().onScreen then
                    _G.Control.CastSpell(spell, pred.CastPos)
                else
                    return
                end
            end
        end
    end
end

class "SimpleKite"

function SimpleKite:__init()
    self:LoadMenu()
    Callback.Add("Tick", function() self:Tick() end)
end

function SimpleKite:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "SimpleKite", name = "dnsSimpleKite °-_-'"})
    self.Menu:MenuElement({id = "kite", name = "Enable SimpleKite", value = true})
end

function SimpleKite:Tick()
    if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
    target = GetTarget(myHero.range + myHero.boundingRadius)

    if target and ValidTarget(target) then
        GaleMouseSpot = self:MoveHelper(target)
    else
        _G.SDK.Orbwalker.ForceMovement = nil
    end
end

function SimpleKite:MoveHelper(unit)
    local EAARangel = unit.range + unit.boundingRadius
    local AARange = myHero.range + myHero.boundingRadius
    local MoveSpot = nil
    local RangeDif = AARange - EAARangel
    local ExtraRangeDist = RangeDif
    local ExtraRangeChaseDist = RangeDif - 100

    local ScanDirection = Vector((myHero.pos-mousePos):Normalized())
    local ScanDistance = GetDistance(myHero.pos, unit.pos) * 0.8
    local ScanSpot = myHero.pos - ScanDirection * ScanDistance
    

    local MouseDirection = Vector((unit.pos-ScanSpot):Normalized())
    local MouseSpotDistance = EAARangel + ExtraRangeDist
    if not IsFacing(unit) then
        MouseSpotDistance = EAARangel + ExtraRangeChaseDist
    end
    if MouseSpotDistance > AARange then
        MouseSpotDistance = AARange
    end

    local MouseSpot = unit.pos - MouseDirection * (MouseSpotDistance)
    local MouseDistance = GetDistance(unit.pos, mousePos)
    local GaleMouseSpotDirection = Vector((myHero.pos-MouseSpot):Normalized())
    local GalemouseSpotDistance = GetDistance(myHero.pos, MouseSpot)
    if GalemouseSpotDistance > 300 then
        GalemouseSpotDistance = 300
    end
    local GaleMouseSpoty = myHero.pos - GaleMouseSpotDirection * GalemouseSpotDistance
    MoveSpot = MouseSpot

    if MoveSpot then
        if GetDistance(myHero.pos, MoveSpot) < 50 or IsUnderEnemyTurret(MoveSpot) then
            _G.SDK.Orbwalker.ForceMovement = nil
        elseif self.Menu.kite:Value() and GetDistance(myHero.pos, unit.pos) <= AARange-50 and (Mode() == "Combo" or Mode() == "Harass") and MouseDistance < 750 then
            _G.SDK.Orbwalker.ForceMovement = MoveSpot
        else
            _G.SDK.Orbwalker.ForceMovement = nil
        end
    end
    return GaleMouseSpoty
end

function OnLoad()
    SimpleKite()
end