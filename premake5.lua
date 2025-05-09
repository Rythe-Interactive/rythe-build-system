--[[
    Rythe uses a build system built on top of Premake5.
    Using the rythe premake module you can define projects and workspaces.
    Projects can either be manually defined, or automatically detected through .rythe_project files.
    .rythe_project files also allows you to customize the project, and report third-party dependencies that don't use the rythe build system.
]]

if(_ACTION ~= nil) then
    newoption {
        trigger = "workspace-name",
        value = "name",
        description = "Name to give you workspace/solution file.",
        default = "rythe"
    }

    newoption {
        trigger = "workspace-location",
        value = "dir",
        description = "Directory to create workspace in.",
    }

    newoption {
        trigger = "single-project",
        value = "project-dir",
        description = "Directory of a project if you only want to have one project.",
    }

    os.chdir(_WORKING_DIR)

    filter("configurations:Debug-no-inline")
        defines { "RYTHE_DISABLE_ALWAYS_INLINE" }

    local r = require("rythe")

    local workspace = {
        name = _OPTIONS["workspace-name"],
        location = _OPTIONS["workspace-location"] or ("build/" .. _ACTION),
        configurations = { "Debug", "Debug-no-inline", "Development", "Release", "Debug-asan", "Release-profiling" }
    }

    r.setup({workspace})
    r.projects.addBuiltInProjects()

    if(_OPTIONS["single-project"] ~= nil) then
        r.projects.load({ location = _OPTIONS["single-project"] })
    else
        r.projects.scan("./")
    end

    r.projects.resolveAllDeps()
    r.projects.sumbitAll()
end