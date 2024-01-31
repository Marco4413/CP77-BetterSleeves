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

local BetterUI = { }

function BetterUI.ButtonAdd()
    local lineHeight = ImGui.GetTextLineHeightWithSpacing()
    ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 0.0)
    ImGui.PushStyleColor(ImGuiCol.Text, .1, .9, 0, 1)
    local res = ImGui.Button("+", lineHeight, lineHeight)
    ImGui.PopStyleColor()
    ImGui.PopStyleVar()
    return res
end

function BetterUI.ButtonRemove()
    local lineHeight = ImGui.GetTextLineHeightWithSpacing()
    ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 0.0)
    ImGui.PushStyleColor(ImGuiCol.Text, .9, .1, 0, 1)
    local res = ImGui.Button("-", lineHeight, lineHeight)
    ImGui.PopStyleColor()
    ImGui.PopStyleVar()
    return res
end

function BetterUI.DragFloat(...)
    ImGui.PushItemWidth(100)
    local value, changed = ImGui.DragFloat(...)
    ImGui.PopItemWidth()
    return value, changed
end

function BetterUI.FitNButtonsInContentRegionAvail(n)
    local widthAvail, _ = ImGui.GetContentRegionAvail()
    local lineHeight = ImGui.GetTextLineHeightWithSpacing()
    local buttonWidth = widthAvail/n - 2.5 * (n-1)
    return buttonWidth, lineHeight
end

function BetterUI.FitButtonN(n, label)
    return ImGui.Button(label, BetterUI.FitNButtonsInContentRegionAvail(n))
end

return BetterUI
