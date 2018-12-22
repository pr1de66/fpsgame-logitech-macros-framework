-------------------------------------------------
--  The following is for polling.  Do not alter.
-------------------------------------------------
_StartUpParameters = {
    PollDevice = "mouse",
    PollDelay = 10,
    AutoTaskSleep = false,
}
function _PreEvent() end
function _PostEvent()
    _TaskHandler.Execute()
end
function OnEvent(event, arg, family)
    if event == "PROFILE_ACTIVATED" then
        _TaskHandler = InitTaskHandler()
        Poll = InitPolling(_StartUpParameters.PollDelay, _StartUpParameters.PollDevice, _PreEvent, _PostEvent)
    end
    Poll.Execute(event, arg, family)
end
 
----------------------------
-- Polling Class
----------------------------
function InitPolling(PollDelay, PollDevice, PreOnEventFunc, PostOnEventFunc)
    local self = {
        PollDelay = PollDelay,
        PollDevice = PollDevice,
        PreOnEventFunc = PreOnEventFunc,
        PostOnEventFunc = PostOnEventFunc,
        Sleep = Sleep_hook,
    }
    local function CreateEvent() SetMKeyState(1, self.PollDevice) end
    local function OnEvent(event, arg, family)
        if self.PreOnEventFunc then self.PreOnEventFunc() end
        _OnEvent(event, arg, family)
        if self.PostOnEventFunc then self.PostOnEventFunc() end
    end
    function self.Execute(event, arg, family)
        if event == "PROFILE_ACTIVATED" then
            if _OnActivated then _OnActivated(event, arg, family) end
            OnEvent(event, arg, family)
            CreateEvent()                                   -- initiates the first polling event
        elseif event == "M_RELEASED" and family == self.PollDevice then
            OnEvent("POLLING", 0, self.PollDevice)
            CreateEvent()
            self.Sleep(self.PollDelay)
        elseif event == "M_PRESSED" and family == self.PollDevice then
            OnEvent("POLLING", 0, self.PollDevice)
            self.Sleep(self.PollDelay)
        elseif event == "PROFILE_DEACTIVATED" then
            if _OnDeactivated then  _OnDeactivated(event, arg, family) end
        else
            OnEvent(event, arg, family)
        end
    end
    function self.SetPreOnEventFunc(func) self.PreOnEventFunc = func end
    function self.SetPostOnEventFunc(func) self.PosOnEventFunc = func end
    return self
end
 
------------------------
-- Task Class
------------------------
function TaskSleep(delay) return coroutine.yield(delay) end
function NewTask(func, ...)
    local self = {
        _Func = func,
        _Running = false,
        _Co = nil,
        _ResumeRunningTime = -1,
        _AtStart = false,
        _Repeat = false,
        _Vars = nil,
        _TH = _TaskHandler or nil,
    }
    function self.ChangeVars(...)   self._Vars = { ... } end
    function self.SetRepeat(r)  self._Repeat = r end
    function self.GetRepeat()   return self._Repeat end
    function self.Create()
        self._ResumeRunningTime = -1
        self._Running = false
        self._Co = coroutine.create(self._Func)
        self._AtStart = true
    end
    function self.Start()
        if not self.IsAtStart() or not self.IsCreated() then
            self.Create()
        end
        self._Running = true
    end
    function self.Stop() self._Running = false; self._Co = nil end
    function self.GetStatus()
        if self._Co then return coroutine.status(self._Co)
        else return nil end
    end
    function self.IsAtStart() return self._AtStart end
    function self.IsAtEnd() return self.IsDead() end
    function self.IsCreated()
        if self._Co then return true
        else return false   end
    end
    function self.IsDead()
        if self._Co and self.GetStatus() == "dead" then return true
        else return false   end
    end
    function self.IsRunning()
        if self.IsCreated() and self._Running and not self.IsDead() then return true
        else return false end
    end
    function self.IsReady()
        if self._Running and self.IsCreated() and not self.IsDead()
            and self._ResumeRunningTime <= GetRunningTime() then
            return true
        else return false end
    end
    function self.Pause() self._Running = false end
    function self.Resume() self._Running = true end
    function self.Execute()
        if self.GetRepeat() and self.IsDead() and self._Running then self.Start() end
        if self.IsReady() then
            local status, delay = coroutine.resume(self._Co, unpack(self._Vars))
            self._AtStart = false
            if delay then self._ResumeRunningTime = delay + GetRunningTime()
            else self._ResumeRunningTime = -1 end
            return status
        end
    end
    function self.Destroy()
        if self._TH then self._TH.RemoveTask(self) end
        self = nil
        return nil
    end
    function self.Remove() self.Destroy() end
    self.ChangeVars(...)
    self.Create()
    if self._TH then self._TH.AddTask(self) end
    return self
end
 
--------------------------
--  TaskHandler
--------------------------
function InitTaskHandler()
    local self = {  _TaskList = {}, }
    function self.AddTask(Task) self._TaskList[Task] = true end
    function self.RemoveTask(Task) self._TaskList[Task] = nil end
    function self.Execute()
        for k,v in pairs(self._TaskList) do k.Execute() end
    end
    return self
end
coroutine.running_hook = coroutine.running
function coroutine.running()
    local v = coroutine.running_hook()
    return v
end
Sleep_hook = Sleep
function Sleep(d)
    if _StartUpParameters.AutoTaskSleep and coroutine.running() then return TaskSleep(d)
    else return Sleep_hook(d) end
end



---------------------------
---Framework for Weapons---
---------------------------
noWeapon = "clear"
function initWeapon(weapon)
    weapon.pdata = {}
    for shotTimes = 2 , weapon.ammo do
        local hchange = weapon.data[shotTimes-1][1] - weapon.data[shotTimes][1]
        local vchange = weapon.data[shotTimes-1][2] - weapon.data[shotTimes][2]
        hchange = math.floor(hchange * weapon.factor)
        vchange = math.floor(vchange * weapon.factor)
        weapon.pdata[shotTimes] = {hchange,vchange}
    end
end

function onWeapon(weapon)
    local shotTimes = 2
    local startTime = GetRunningTime()
    MoveMouseRelative(weapon.pdata[2][1],weapon.pdata[2][2])
    while shotTimes < weapon.ammo do
        local currentTime = GetRunningTime()
        if currentTime-startTime >weapon.interval then
            shotTimes = shotTimes + 1
            startTime = startTime + weapon.interval
            local hchange = weapon.pdata[shotTimes][1]
            local vchange = weapon.pdata[shotTimes][2]
            MoveMouseRelative(hchange,vchange)
        end
        TaskSleep(10)
    end
end

function onCurrentWeapon()
    onWeapon(config.currentWeapon)
end

--------------------------
----Global Configs--------
--------------------------
config = {}
config.task = nil
config.currentWeapon = nil
config.keyBindings = {}

function bindKey(key,func)
    config.keyBindings[key] = func
end

function _OnEvent(event,arg)
    EnablePrimaryMouseButtonEvents(true)
    if event == "MOUSE_BUTTON_PRESSED" and config.keyBindings[arg] ~= nil then
        if config.keyBindings[arg] == "clear" then
            config.currentWeapon = nil
        else
            config.currentWeapon = config.keyBindings[arg]
        end
    end
    if event == "MOUSE_BUTTON_PRESSED" and arg == 1 and config.currentWeapon ~= nil then
        config.task = NewTask(onCurrentWeapon)
        config.task.Start()
    end

    if event == "MOUSE_BUTTON_RELEASED" and arg == 1 and config.currentWeapon ~= nil then
        config.task.Destroy()
    end
end

