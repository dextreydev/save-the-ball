local love = require("love")

function love.conf(t)
	t.console = false
	t.window.resizable = false
	t.window.width = 1280
	t.window.height = 720
	t.identity = "savetheball-alpha"
	t.window.icon = "images/enemy.png"
end