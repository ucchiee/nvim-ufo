local api = vim.api
local fn = vim.fn

local buffer     = require('ufo.model.foldbuffer')
local event      = require('ufo.lib.event')
local disposable = require('ufo.lib.disposable')
local bufmanager = require('ufo.bufmanager')
local utils      = require('ufo.utils')
local driver     = require('ufo.fold.driver')
local log        = require('ufo.lib.log')

---@class UfoFoldBufferManager
---@field buffers UfoFoldBuffer[]
---@field providerSelector function
---@field disposables UfoDisposable[]
local FoldBufferManager = {
    buffers = {},
    disposables = {}
}

local initialized

---
---@param namespace number
---@param selector function
---@return UfoFoldBufferManager
function FoldBufferManager:initialize(namespace, selector)
    if initialized then
        return self
    end
    self.ns = namespace
    self.providerSelector = selector
    local disposables = {
        disposable:create(function()
            for _, fb in pairs(self.buffers) do
                fb:dispose()
            end
            self.buffers = {}
        end)
    }
    event:on('BufDetach', function(bufnr)
        local fb = self:get(bufnr)
        if fb then
            fb:dispose()
        end
        self.buffers[bufnr] = nil
    end, disposables)
    event:on('BufReload', function(bufnr)
        local fb = self:get(bufnr)
        if fb then
            fb:dispose()
        end
    end, disposables)

    local function optChanged(bufnr, old, new)
        if old ~= new then
            local fb = self:get(bufnr)
            if fb then
                fb.providers = nil
            end
        end
    end

    event:on('BufTypeChanged', optChanged, disposables)
    event:on('FileTypeChanged', optChanged, disposables)
    event:on('BufLinesChanged', function(bufnr, _, firstLine, lastLine, lastLineUpdated)
        if lastLineUpdated - lastLine == 0 then
            return
        end
        local fb = self:get(bufnr)
        if fb then
            fb:handleFoldedLinesChanged(firstLine, lastLine, lastLineUpdated)
        end
    end, disposables)
    self.disposables = disposables
    self.providerSelector = selector
    initialized = true
    return self
end

---
---@param bufnr number
---@return boolean
function FoldBufferManager:attach(bufnr)
    local fb = self:get(bufnr)
    if not fb then
        self.buffers[bufnr] = buffer:new(bufmanager:get(bufnr), self.ns)
    end
    return not fb
end

---
---@param bufnr number
---@return UfoFoldBuffer
function FoldBufferManager:get(bufnr)
    return self.buffers[bufnr]
end

function FoldBufferManager:dispose()
    disposable.disposeAll(self.disposables)
    self.disposables = {}
    initialized = false
end

function FoldBufferManager:parseBufferProviders(fb, selector)
    if not utils.isBufLoaded(fb.bufnr) then
        return
    end
    if not selector then
        fb.providers = {'lsp', 'indent'}
        return
    end
    local res
    local providers = selector(fb.bufnr, fb:filetype(), fb:buftype())
    local t = type(providers)
    if t == 'nil' then
        res = {'lsp', 'indent'}
    elseif t == 'string' or t == 'function' then
        res = {providers}
    elseif t == 'table' then
        res = {}
        for _, m in ipairs(providers) do
            if #res == 2 then
                break
            end
            table.insert(res, m)
        end
    else
        res = {''}
    end
    fb.providers = res
end

function FoldBufferManager:isFoldMethodsDisabled(fb)
    if not fb.providers then
        self:parseBufferProviders(fb, self.providerSelector)
    end
    return not fb.providers or fb.providers[1] == ''
end

---
---@param bufnr number
---@param ranges? UfoFoldingRange[]
---@return boolean
function FoldBufferManager:applyFoldRanges(bufnr, ranges)
    local fb = self:get(bufnr)
    if not fb then
        return false
    end
    local winid = fn.bufwinid(bufnr)
    local changedtick = fb:changedtick()
    if ranges then
        if utils.mode() ~= 'n' or not utils.isWinValid(winid) or
            utils.isDiffOrMarkerFold(winid) then
            fb.version = changedtick
            fb.foldRanges = ranges
            fb.status = 'pending'
            return false
        end
    elseif changedtick ~= fb.version or not utils.isWinValid(winid) then
        return false
    end
    local rowPairs = {}
    if not fb.scanned then
        for _, range in ipairs(fb:scanFoldedRanges(winid)) do
            local row, endRow = range[1], range[2]
            rowPairs[row] = endRow
        end
        fb.scanned = true
    else
        local marks = api.nvim_buf_get_extmarks(fb.bufnr, self.ns, 0, -1, {details = true})
        for _, m in ipairs(marks) do
            local row, endRow = m[2], m[4].end_row
            rowPairs[row] = endRow
        end
    end
    fb.version = changedtick
    if ranges then
        fb.foldRanges = ranges
    end
    log.info('apply fold ranges:', fb.foldRanges)
    log.info('apply fold rowPairs:', rowPairs)
    driver:createFolds(winid, fb.foldRanges, rowPairs)
    return true
end

return FoldBufferManager
