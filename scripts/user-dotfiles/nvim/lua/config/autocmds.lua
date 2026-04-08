-- ============================================================================
-- Neovim 特有的自动命令 (与 .vimrc 不重复)
-- ============================================================================

-- 光标形状设置 (GUI)
vim.api.nvim_create_autocmd("InsertEnter", {
  callback = function()
    vim.opt.guicursor = "n-v-c-sm:block,i-ci-ve:ver25,r-cr-o:hor20"
  end,
})

vim.api.nvim_create_autocmd("InsertLeave", {
  callback = function()
    vim.opt.guicursor = "n-v-c-sm:block,i-ci-ve:ver25,r-cr-o:hor20"
  end,
})

-- 自动保存文件
vim.api.nvim_create_augroup("AutoSave", { clear = true })
vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged" }, {
  group = "AutoSave",
  callback = function()
    if not vim.bo.readonly and vim.bo.buftype == "" and vim.fn.expand("%") ~= "" then
      vim.cmd("silent! wall")
    end
  end,
})
