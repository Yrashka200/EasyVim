vim.g.mapleader = " "
vim.g.maplocalleader = " "

local map = vim.keymap.set


map("n", "<leader>w", ":w<CR>", { desc = "Сохранить файл" })
map("n", "<leader>q", ":q<CR>", { desc = "Выйти" })
map("n", "<leader>h", ":nohlsearch<CR>", { desc = "Убрать подсветку поиска" })


map("n", "<C-h>", "<C-w>h", { desc = "Окно влево" })
map("n", "<C-j>", "<C-w>j", { desc = "Окно вниз" })
map("n", "<C-k>", "<C-w>k", { desc = "Окно вверх" })
map("n", "<C-l>", "<C-w>l", { desc = "Окно вправо" })


map("n", "<S-l>", ":bnext<CR>", { desc = "Следующий буфер" })
map("n", "<S-h>", ":bprevious<CR>", { desc = "Предыдущий буфер" })
map("n", "<leader>x", ":bdelete<CR>", { desc = "Закрыть буфер" })