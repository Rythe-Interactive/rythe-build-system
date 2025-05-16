--[[
    Rythe uses a build system built on top of Premake5.
    Using the rythe premake module you can define projects and workspaces.
    Projects can either be manually defined, or automatically detected through .rythe_project files.
    .rythe_project files also allows you to customize the project, and report third-party dependencies that don't use the rythe build system.
]]

newoption {
    trigger = "enumerate-projects",
    description = "Enumerate all available projects using scan(\"./\")",
    category = "Utility"
}

newoption {
    trigger = "workspace-name",
    value = "NAME",
    description = "Name to give you workspace/solution file.",
    default = "rythe",
    category = "Workspace setup"
}

newoption {
    trigger = "workspace-location",
    value = "PATH",
    description = "Directory to create workspace in.",
    category = "Workspace setup"
}

newoption {
    trigger = "single-project",
    value = "PATH",
    description = "Directory of a project if you only want to have one project.",
    category = "Workspace setup"
}

if(_OPTIONS["enumerate-projects"] ~= nil) then
    os.chdir(_WORKING_DIR)
    
    local r = require("rythe")
    r.projects.clearAll()
    r.projects.addBuiltInProjects()
    r.projects.scan("./")
    r.projects.resolveAllDeps()

    r.utils.printIndented("Found projects:")
    r.utils.pushIndent()
    for projectId, project in pairs(r.loadedProjects) do
        r.utils.printIndented(projectId)
    end
    r.utils.popIndent()
end

if(_ACTION ~= nil) then
    os.chdir(_WORKING_DIR)

    filter("configurations:Debug-no-inline")
        defines { "RYTHE_DISABLE_ALWAYS_INLINE" }

    local r = require("rythe")

    r.projects.clearAll()

    r.projects.addBuiltInProjects()

    if(_OPTIONS["single-project"] ~= nil) then
        r.projects.load({ location = _OPTIONS["single-project"] })
    else
        r.projects.scan("./")
    end

    r.projects.resolveAllDeps()

    local workspace = {
        name = _OPTIONS["workspace-name"],
        location = _OPTIONS["workspace-location"] or ("build/" .. _ACTION),
        configurations = { "Debug", "Debug-no-inline", "Development", "Release", "Debug-asan", "Release-profiling" }
    }

    r.setupWorkspace(workspace)
        r.utils.pushIndent()
        r.projects.submitAll()
        r.utils.popIndent()

end