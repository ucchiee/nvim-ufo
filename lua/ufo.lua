local api = vim.api

---Export methods to the users, `require('ufo').method(...)`
---@class Ufo
local M = {}

---Peek the folded line under cursor, any motions in the normal window will close the floating window.
---@param maxHeight? number max height for floating window, default 20
---@param nextLineIncluded? boolean include the next line of last line of closed fold, default true
---@param enter? boolean enter the floating window, default false
---@return number? winid, number? bufnr return the winid and bufnr if successful, otherwise return nil
function M.peekFoldedLinesUnderCursor(maxHeight, nextLineIncluded, enter)
    return require('ufo.preview'):peekFoldedLinesUnderCursor(maxHeight, nextLineIncluded, enter)
end

---Go to previous start fold. Neovim can't go to previous start fold directly, it's an extra motion.
function M.goPreviousStartFold()
    require('ufo.action').goPreviousStartFold()
end

---Go to previous closed fold. It's an extra motion.
function M.goPreviousClosedFold()
    require('ufo.action').goPreviousClosedFold()
end

---Go to next closed fold. It's an extra motion.
function M.goNextClosedFold()
    return require('ufo.action').goNextClosedFold()
end

---Close all folds but keep foldlevel
function M.closeAllFolds()
    return require('ufo.action').closeAllFolds()
end

---Open all folds but keep foldlevel
function M.openAllFolds()
    return require('ufo.action').openAllFolds()
end

---Inspect ufo information by bufnr
---@param bufnr? number current buffer default
function M.inspect(bufnr)
    bufnr = bufnr or api.nvim_get_current_buf()
    local msg = require('ufo.main').inspectBuf(bufnr)
    if not msg then
        vim.notify(('Buffer %d has not been attached.'):format(bufnr), vim.log.levels.ERROR)
    else
        vim.notify(table.concat(msg, '\n'), vim.log.levels.INFO)
    end
end

---Enable ufo
function M.enable()
    require('ufo.main').enable()
end

---Disable ufo
function M.disable()
    require('ufo.main').disable()
end

---Check whether the buffer has been attached
---@param bufnr? number current buffer default
---@return boolean
function M.hasAttached(bufnr)
    return require('ufo.main').hasAttached(bufnr)
end

---Attach bufnr to enable all features
---@param bufnr? number current buffer default
function M.attach(bufnr)
    require('ufo.main').attach(bufnr)
end

---Detach bufnr to disable all features
---@param bufnr? number current buffer default
function M.detach(bufnr)
    require('ufo.main').detach(bufnr)
end

---Enable to get folds and update them at once
---@param bufnr? number current buffer default
---@return string|'start'|'pending'|'stop' status
function M.enableFold(bufnr)
    return require('ufo.main').enableFold(bufnr)
end

---Disable to get folds
---@param bufnr? number current buffer default
---@return string|'start'|'pending'|'stop' status
function M.disableFold(bufnr)
    return require('ufo.main').disableFold(bufnr)
end

---Get foldingRange from the ufo internal providers by name
---@param providerName string
---@param bufnr number
---@return UfoFoldingRange
function M.getFolds(providerName, bufnr)
    local ok, res = pcall(require, 'ufo.provider.' .. providerName)
    assert(ok, ([[Can't find %s provider]]):format(providerName))
    return res.getFolds(bufnr)
end

---Setup configuration and enable ufo
---@param opts? UfoConfig
function M.setup(opts)
    opts = opts or {}
    M._config = opts
    M.enable()
end

---------------------------------------setFoldVirtTextHandler---------------------------------------
---@class UfoFoldVirtTextHandlerContext
---@field bufnr number buffer for closed fold
---@field winid number window for closed fold
---@field text string text for the first line of closed fold
---@field end_virt_text ExtmarkVirtTextChunk[] contained text and highlight for end lnum

---@class ExtmarkVirtTextChunk
---@field text string
---@field highlight string|number

---Set a fold virtual text handler for a buffer, will override global handler if it's existed.
---Ufo actually uses a virtual text with \`nvim_buf_set_extmark\` to overlap the first line of closed fold
---run \`:h nvim_buf_set_extmark | call search('virt_text')\` for detail
---@diagnostic disable: undefined-doc-param
---Detial for handler function:
---@param virtText ExtmarkVirtTextChunk[] contained text and highlight captured by Ufo, export to caller
---@param lnum number first line of closed fold, like \`v:foldstart\` in foldtext()
---@param endLnum number last line of closed fold, like \`v:foldend\` in foldtext()
---@param width number text area width, exclude foldcolumn, signcolumn and numberwidth
---@param truncate fun(str: string, width: number): string truncate the str to become specific width,
---return width of string is equal or less than width (2nd argument).
---For example: '1': 1 cell, '你': 2 cells, '2': 1 cell, '好': 2 cells
---truncate('1你2好', 1) return '1'
---truncate('1你2好', 2) return '1'
---truncate('1你2好', 3) return '1你'
---truncate('1你2好', 4) return '1你2'
---truncate('1你2好', 5) return '1你2'
---truncate('1你2好', 6) return '1你2好'
---truncate('1你2好', 7) return '1你2好'
---truncate('1你2好', 8) return '1你2好'
---@param ctx UfoFoldVirtTextHandlerContext the context used by ufo, export to caller

---@alias UfoFoldVirtTextHandler fun(virtText: ExtmarkVirtTextChunk[], lnum: number, endLnum: number, width: number, truncate: fun(str: string, width: number), ctx: UfoFoldVirtTextHandlerContext): ExtmarkVirtTextChunk
---
---@param bufnr number
---@param handler UfoFoldVirtTextHandler
function M.setFoldVirtTextHandler(bufnr, handler)
    vim.validate({bufnr = {bufnr, 'number', true}, handler = {handler, 'function'}})
    require('ufo.decorator'):setVirtTextHandler(bufnr, handler)
end

---@diagnostic disable: undefined-doc-param
---------------------------------------setFoldVirtTextHandler---------------------------------------

return M
