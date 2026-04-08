-- 精简版配置：只保留核心功能和键位映射（完全移除 LazyVim）
return {
  -- ===== 主题 =====
  
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("tokyonight").setup({ style = "moon" })
      vim.cmd([[colorscheme tokyonight]])
    end,
  },
  
  -- ===== 依赖插件 =====
  
  { "nvim-lua/plenary.nvim" },
  { "MunifTanjim/nui.nvim" },
  { "nvim-tree/nvim-web-devicons" },
  
  -- ===== 禁用不必要的插件 =====
  
  -- 禁用 LSP 相关（如果需要LSP可以注释掉这部分）
  { "neovim/nvim-lspconfig", enabled = false },
  { "williamboman/mason.nvim", enabled = false },
  { "williamboman/mason-lspconfig.nvim", enabled = false },
  
  -- 禁用补全
  { "saghen/blink.cmp", enabled = false },
  { "hrsh7th/nvim-cmp", enabled = false },
  
  -- 禁用 Treesitter（语法高亮）
  { "nvim-treesitter/nvim-treesitter", enabled = false },
  { "nvim-treesitter/nvim-treesitter-textobjects", enabled = false },
  { "windwp/nvim-ts-autotag", enabled = false },
  
  -- 禁用代码格式化和Lint
  { "stevearc/conform.nvim", enabled = false },
  { "mfussenegger/nvim-lint", enabled = false },
  
  -- 禁用UI相关
  { "folke/noice.nvim", enabled = false },
  { "rcarriga/nvim-notify", enabled = false },
  { "stevearc/dressing.nvim", enabled = false },
  { "akinsho/bufferline.nvim", enabled = false },
  { "nvim-lualine/lualine.nvim", enabled = false },
  
  -- 禁用仪表板
  { "folke/snacks.nvim", enabled = false },
  { "goolord/alpha-nvim", enabled = false },
  { "nvimdev/dashboard-nvim", enabled = false },
  { "nvim-mini/mini.starter", enabled = false },
  
  -- 禁用其他不必要的插件
  { "folke/flash.nvim", enabled = false },
  { "folke/trouble.nvim", enabled = false },
  { "folke/todo-comments.nvim", enabled = false },
  { "MagicDuck/grug-far.nvim", enabled = false },
  { "echasnovski/mini.pairs", enabled = false },
  { "echasnovski/mini.ai", enabled = false },
  { "folke/persistence.nvim", enabled = false },
  { "folke/lazydev.nvim", enabled = false },
  
  -- 禁用 Git 集成
  { "lewis6991/gitsigns.nvim", enabled = false },
  
  -- ===== 保留的核心插件 =====
  
  -- 文件浏览器（简化版）
  {
    "nvim-neo-tree/neo-tree.nvim",
    cmd = "Neotree",
    keys = {
      { "<leader>e", "<cmd>Neotree toggle<cr>", desc = "Toggle file explorer" },
    },
    opts = {
      filesystem = {
        filtered_items = {
          visible = true,
          hide_dotfiles = false,
          hide_gitignored = false,
        },
      },
    },
  },
  
  -- Telescope（文件搜索，保留核心功能）
  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find files" },
      { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Grep text" },
      { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Find buffers" },
      { "<leader>fr", "<cmd>Telescope oldfiles<cr>", desc = "Recent files" },
    },
    opts = {
      defaults = {
        file_ignore_patterns = { "node_modules", ".git/" },
      },
    },
  },
  
  -- Telescope FZF 扩展
  {
    "nvim-telescope/telescope-fzf-native.nvim",
    build = "make",
  },
  
  -- 注释插件（保留，因为键位映射依赖它）
  {
    "numToStr/Comment.nvim",
    event = "VeryLazy",
    config = function()
      require("Comment").setup()
    end,
  },
  
  -- 用户自定义插件（对齐等）
  {
    "junegunn/vim-easy-align",
    event = "VeryLazy",
    keys = {
      { "ga", "<Plug>(EasyAlign)", mode = { "n", "x" }, desc = "Easy align" },
    },
  },
  
  {
    "dhruvasagar/vim-table-mode",
    event = "VeryLazy",
    cmd = "TableModeToggle",
  },
  
  {
    "machakann/vim-highlightedyank",
    event = "VeryLazy",
  },
  
  -- Which-key（显示键位提示，可选）
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "modern",
    },
  },
}
