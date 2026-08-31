-- R63 GUI GitHub loader
-- CHANGE ONLY THESE TWO VALUES:
local GITHUB_USERNAME = "YOUR_USERNAME"
local GITHUB_REPOSITORY = "YOUR_REPOSITORY"

local BASE = ("https://raw.githubusercontent.com/%s/%s/main"):format(
    GITHUB_USERNAME,
    GITHUB_REPOSITORY
)

getgenv().R63_REPO_BASE = BASE
loadstring(game:HttpGet(BASE .. "/hub.lua"))()
