--[[
Copyright (c) 2024 [Marco4413](https://github.com/Marco4413/CP77-BetterSleeves)

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
]]

local Scheduler = { }

function Scheduler.New()
    return setmetatable({
        _tasks = {},
        _logger = (function() end),
    }, {
        __index = Scheduler
    })
end

function Scheduler:SetLogger(logger)
    self._logger = logger or (function() end)
end

function Scheduler:SetTask(name, callback, delay)
    local task = self._tasks[name]
    if task and task.timer >= delay then return; end

    self._tasks[name] = {
        callback = callback,
        delay = delay,
        timer = delay,
    }
end

function Scheduler:DelTask(name)
    self._tasks[name] = nil
end

function Scheduler:GetTask(name)
    local task = self._tasks[name]
    return {
        callback = task.callback,
        delay = task.delay,
        timer = task.timer,
    }
end

function Scheduler:HasTask(name)
    return self._tasks[name] ~= nil
end

function Scheduler:Update(dt)
    for name, task in next, self._tasks do
        task.timer = task.timer - dt
        if task.timer <= 0 then
            local ok = pcall(task.callback)
            self._tasks[name] = nil
            if not ok then
                self._logger("There was an error while running task '" .. name .. "'.")
            end
        end
    end
end

return Scheduler
